// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

interface IAssetProvider {
  struct ProviderInfo {
    string key;  // short and unique identifier of this provider (e.g., "asset")
    string name; // human readable display name (e.g., "Asset Store")
    IAssetProvider provider;
  }
  function getProviderInfo() external view returns(ProviderInfo memory);
  // This function returns SVGPart and the tag. SVGPart consists of one or more SVG elements.
  // The tag specifies the identifier of the SVG element to be displayed (using <use> tag).
  // The tag is the combination of the provider key and assetId (e.e., "asset123")
  function generateSVGPart(uint256 _assetId) external view returns(string memory, string memory);
  // This function returns the number of supplies available from this provider. 
  // If the total supply is 100, ids of available assets are 0,1,...99.
  // The generative providers returns 0, which indicates the provider dynamically generates
  // supplies using the given assetId as the random seed (deterministic).
  function totalSupply() external view returns(uint256);
}

interface IAssetProviderRegistry {
  event ProviderRegistered(address from, uint256 _providerId);
  function registerProvider(IAssetProvider _provider) external returns(uint256);
  function providerCount() external view returns(uint256);
  function getProvider(uint256 _providerId) external view returns(IAssetProvider.ProviderInfo memory);
  function getProviderId(string memory _key) external view returns(uint256);
}

// IAssetStore is the inteface for consumers of the AsseCompoer.
interface IAssetComposer {
  struct AssetLayer {
    uint256 assetId; // either compositeId or assetId
    string provider; // provider name   
    string fill; // optional fill color
    string transform; // optinal transform
  }

  event CompositionRegistered(address from, uint256 compositionId);
  function registerComposition(AssetLayer[] memory _infos) external returns(uint256);
  function generateSVGPart(uint256 _assetId) external view returns(string memory, string memory);
}