// SPDX-License-Identifier: MIT

/*
 * AssetComposer allows developers to create a composition from a collection of
 * assets (in AssetStore) and compositions.
 *
 * Created by Satoshi Nakajima (@snakajima)
 */

pragma solidity ^0.8.6;

import { Ownable } from '@openzeppelin/contracts/access/Ownable.sol';
import { IAssetStore, IAssetStoreEx } from './interfaces/IAssetStore.sol';
import { IStringValidator } from './interfaces/IStringValidator.sol';
import { IAssetProvider, IAssetProviderRegistry, IAssetComposer } from './interfaces/IAssetComposer.sol';
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract AssetComposerCore is IAssetProviderRegistry {
  mapping(string => uint256) providerIds; // +1
  uint256 nextProvider;
  mapping(uint256 => ProviderInfo) providers;

  IAssetStoreEx public immutable assetStore;

  constructor(IAssetStoreEx _assetStore) {
    assetStore = _assetStore;
  }

  function registerProvider(ProviderInfo memory _providerInfo) external override returns(uint256 providerId) {
    require(providerIds[_providerInfo.name]==0, "AssetCompooser:registerProvider, already registered");
    providers[nextProvider++] = _providerInfo;
    providerIds[_providerInfo.name] = nextProvider; // @notive: providerID + 1
    providerId = nextProvider - 1; 
    emit ProviderRegistered(msg.sender, providerId);
  }

  function providerCount() external view override returns(uint256) {
    return nextProvider;
  }

  function getProvider(uint256 _providerId) public view override returns(ProviderInfo memory) {
    return providers[_providerId];
  }

  function getProviderId(string memory _name) public view override returns(uint256) {
    uint256 idPlusOne = providerIds[_name];
    require(idPlusOne > 0, string(abi.encodePacked("AssestComposer:getProviderId, the provider does not exist:", _name)));
    return idPlusOne - 1;
  }
}

abstract contract AssetComposerAdmin is AssetComposerCore, Ownable {
  // Upgradable admin (only by owner)
  address public admin;

  /*
   * It allows us to disable indivial assets, just in case. 
   */
  mapping(uint256 => bool) disabled;

  constructor(IAssetStoreEx _assetStore) AssetComposerCore(_assetStore) {
    admin = owner();
  }

  modifier onlyAdmin() {
    require(owner() == _msgSender() || admin == _msgSender(), "AssetComposer: caller is not the admin");
    _;
  }

  function setAdmin(address _admin) external onlyOwner {
    admin = _admin;
  }  

  function setDisabled(uint256 _compositionId, bool _status) external onlyAdmin {
    disabled[_compositionId] = _status;
  }

  modifier enabled(uint256 _compositionId) {
    require(disabled[_compositionId] != true, "AssetComposer: this composition is diabled");
    _;    
  }
}

contract AssetComposer is AssetComposerAdmin, IAssetComposer, IAssetProvider {
  using Strings for uint256;

  struct ProviderAsset {
    uint128 providerId;
    uint128 assetId;
  }

  uint256 public nextCompositionId;
  mapping(uint256 => uint256) internal layerCounts; 
  mapping(uint256 => mapping(uint256 => ProviderAsset)) internal assets;
  mapping(uint256 => mapping(uint256 => bytes)) internal transforms; // optional
  mapping(uint256 => mapping(uint256 => bytes)) internal fills; // optinoal

  constructor(IAssetStoreEx _assetStore) AssetComposerAdmin(_assetStore) {
  }

  /**
    * @notice register a new composition by specifying asset layers.
    */
  function registerComposition(AssetLayer[] memory _layers) external override returns(uint256 compositionId) {
    IStringValidator validator = assetStore.getStringValidator();
    compositionId = nextCompositionId++;
    layerCounts[compositionId] = _layers.length;

    for (uint256 i=0; i<_layers.length; i++) {
      AssetLayer memory info = _layers[i];
      uint256 assetId = info.assetId;
      uint256 providerId = getProviderId(info.provider);
      assets[compositionId][i] = ProviderAsset(uint128(providerId), uint128(assetId)); 
      bytes memory transform = bytes(info.transform);
      if (transform.length > 0) {
        require(validator.validate(transform), "register: Invalid transform");
        transforms[compositionId][i] = transform;
      }
      bytes memory fill = bytes(info.fill);
      if (fill.length > 0) {
        require(validator.validate(fill), "register: Invalid fill");
        fills[compositionId][i] = fill;
      }
    }
    emit CompositionRegistered(msg.sender, compositionId);
  }

  /**
    * @notice returns a SVG part (and the tag) that represents the specified composition.
    */
  function generateSVGPart(uint256 _compositionId) public view override(IAssetComposer, IAssetProvider) enabled(_compositionId) returns(string memory, string memory) {
    uint256 layerLength = layerCounts[_compositionId];
    bytes memory defs;
    bytes memory uses;
    string memory svgPart;
    string memory tagId;
    for (uint256 i=0; i < layerLength; i++) {
      ProviderAsset memory assetId = assets[_compositionId][i];
      ProviderInfo memory info = getProvider(uint256(assetId.providerId));
      (svgPart, tagId) = info.provider.generateSVGPart(uint256(assetId.assetId));
      defs = abi.encodePacked(defs, svgPart);
      uses = abi.encodePacked(uses, ' <use href="#', tagId, '"');
      bytes memory option = transforms[_compositionId][i];
      if (option.length > 0) {
        uses = abi.encodePacked(uses, ' transform="', option, '"');
      }
      option = fills[_compositionId][i];
      if (option.length > 0) {
        uses = abi.encodePacked(uses, ' fill="', option, '"');
      }
      uses = abi.encodePacked(uses, ' />\n');
    }
    tagId = string(abi.encodePacked('comp', _compositionId.toString()));
    svgPart = string(abi.encodePacked(
      defs,
      '<g id="', tagId, '" >\n',
      uses,
      '</g>\n'
    ));    
    return (svgPart, tagId);
  }

  function totalSupply() external view override returns(uint256) {
    return nextCompositionId;
  }
}
