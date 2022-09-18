// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
pragma experimental "ABIEncoderV2";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AddressArrayUtils } from "./lib/AddressArrayUtils.sol";
import { PreciseUnitMath } from "./lib/PreciseUnitMath.sol";
import { IOracleAdapter } from "./interfaces/IOracleAdapter.sol";


/**
 * @title PriceOracle
 *
 * Contract that returns the price for any given asset pair. Price is retrieved either directly from an oracle,
 * calculated using common asset pairs, or uses external data to calculate price.
 * Note: Prices are returned in preciseUnits (i.e. 18 decimals of precision)
 */
contract PriceOracle is Ownable {

    using PreciseUnitMath for uint256;
    using AddressArrayUtils for address[];

    /* ============ Events ============ */

    event PriceAdded(address indexed _assetOne, address indexed _assetTwo, uint256 _price);
    event PriceRemoved(address indexed _assetOne, address indexed _assetTwo);
    event AdapterAdded(address _adapter);
    event AdapterRemoved(address _adapter);
    event MasterQuoteAssetEdited(address _newMasterQuote);


    /* ============ State Variables ============ */

    // Mapping between assetA/assetB and its associated price
    // Asset 1 -> Asset 2 -> price
    mapping(address => mapping(address => uint256)) public prices;

    // Token address of the bridge asset that prices are derived from if the specified pair price is missing
    address public masterQuoteAsset;

    // List of IOracleAdapters used to return prices of third party protocols (e.g. Uniswap, Compound, Balancer)
    address[] public adapters;

    /* ============ Constructor ============ */

    /**
     * Initialize state variables
     *
     * @param _masterQuoteAsset       Address of asset that can be used to link unrelated asset pairs
     * @param _adapters               List of adapters used to price assets created by other protocols
     */
    constructor(address _masterQuoteAsset, address[] memory _adapters) {
        masterQuoteAsset = _masterQuoteAsset;
        adapters = _adapters;
    }

    /* ============ External Functions ============ */

    /**
     * SYSTEM-ONLY PRIVELEGE: Find price of passed asset pair, if possible. The steps it takes are:
     *  1) Check to see if a direct or inverse price of the pair exists,
     *  2) If not, use masterQuoteAsset to link pairs together (i.e. BTC/ETH and ETH/USDC
     *     could be used to calculate BTC/USDC).
     *  3) If not, check oracle adapters in case one or more of the assets needs external protocol data
     *     to price.
     *  4) If all steps fail, revert.
     *
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @return                  Price of asset pair to 18 decimals of precision
     */
    function getPrice(address _assetOne, address _assetTwo) external view returns (uint256) {
        (bool priceFound, uint256 price) = _getDirectOrInversePrice(_assetOne, _assetTwo);

        if (!priceFound) {
            (priceFound, price) = _getPriceFromMasterQuote(_assetOne, _assetTwo);
        }

        if (!priceFound) {
            (priceFound, price) = _getPriceFromAdapters(_assetOne, _assetTwo);
        }

        require(priceFound, "PriceOracle.getPrice: Price not found.");

        return price;
    }

    /**
     * GOVERNANCE FUNCTION: Add new asset pair price.
     *
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @param _price            Price of assetOne per assetTwo
     * @param _decimals         Price decimals
     */
    function feedPrice(
        address _assetOne,
        address _assetTwo,
        uint256 _price,
        uint8 _decimals
    ) external onlyOwner {
        prices[_assetOne][_assetTwo] = PreciseUnitMath.preciseDiv(_price, 10 ** _decimals);

        emit PriceAdded(_assetOne, _assetTwo, _price);
    }

    /**
     * GOVERNANCE FUNCTION: Remove asset pair's price.
     *
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     */
    function removePrice(address _assetOne, address _assetTwo) external onlyOwner {
        require(
            prices[_assetOne][_assetTwo] > 0,
            "PriceOracle.removePrice: Price doesn't exist."
        );

        delete prices[_assetOne][_assetTwo];

        emit PriceRemoved(_assetOne, _assetTwo);
    }

    /**
     * GOVERNANCE FUNCTION: Add new oracle adapter.
     *
     * @param _adapter         Address of new adapter
     */
    function addAdapter(address _adapter) external onlyOwner {
        require(
            !adapters.contains(_adapter),
            "PriceOracle.addAdapter: Adapter already exists."
        );
        adapters.push(_adapter);

        emit AdapterAdded(_adapter);
    }

    /**
     * GOVERNANCE FUNCTION: Remove oracle adapter.
     *
     * @param _adapter         Address of adapter to remove
     */
    function removeAdapter(address _adapter) external onlyOwner {
        require(
            adapters.contains(_adapter),
            "PriceOracle.removeAdapter: Adapter does not exist."
        );
        adapters = adapters.remove(_adapter);

        emit AdapterRemoved(_adapter);
    }

    /**
     * GOVERNANCE FUNCTION: Change the master quote asset.
     *
     * @param _newMasterQuoteAsset         New address of master quote asset
     */
    function editMasterQuoteAsset(address _newMasterQuoteAsset) external onlyOwner {
        masterQuoteAsset = _newMasterQuoteAsset;

        emit MasterQuoteAssetEdited(_newMasterQuoteAsset);
    }

    /* ============ External View Functions ============ */

    /**
     * Returns an array of adapters
     */
    function getAdapters() external view returns (address[] memory) {
        return adapters;
    }

    /* ============ Internal Functions ============ */

    /**
     * Check if direct or inverse price exists. If so return that price along with boolean indicating
     * it exists. Otherwise return boolean indicating price doesn't exist.
     *
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @return bool             Boolean indicating if price exists
     * @return uint256          Price of asset pair to 18 decimal precision (if exists, otherwise 0)
     */
    function _getDirectOrInversePrice(
        address _assetOne,
        address _assetTwo
    )
        internal
        view
        returns (bool, uint256)
    {
        uint256 price = prices[_assetOne][_assetTwo];

        // Check direct price (asset1 -> asset 2). If exists, then return value
        // Has direct price
        if (price > 0) {
            return (true, price);
        }

        uint256 inversePrice = prices[_assetTwo][_assetOne];

        // If not, check inverse price (asset 2 -> asset 1). If exists, then return 1 / asset1 -> asset2
        if (inversePrice > 0) {
            // Calculate inverse price. The inverse price is 1 (or 1e18) / inverse price
            return (true, PreciseUnitMath.preciseUnit().preciseDiv(inversePrice));
        }

        return (false, 0);
    }

    /**
     * Try to calculate asset pair price by getting each asset in the pair's price relative to master
     * quote asset. Both prices must exist otherwise function returns false and no price.
     *
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @return bool             Boolean indicating if price exists
     * @return uint256          Price of asset pair to 18 decimal precision (if exists, otherwise 0)
     */
    function _getPriceFromMasterQuote(
        address _assetOne,
        address _assetTwo
    )
        internal
        view
        returns (bool, uint256)
    {
        (bool priceFoundOne, uint256 assetOnePrice) = _getDirectOrInversePrice(_assetOne, masterQuoteAsset);
        (bool priceFoundTwo, uint256 assetTwoPrice) = _getDirectOrInversePrice(_assetTwo, masterQuoteAsset);

        if (priceFoundOne && priceFoundTwo) {
            return (true, assetOnePrice.preciseDiv(assetTwoPrice));
        }

        return (false, 0);
    }

    /**
     * Scan adapters to see if one or more of the assets needs external protocol data to be priced. If
     * does not exist return false and no price.
     *
     * @param _assetOne         Address of first asset in pair
     * @param _assetTwo         Address of second asset in pair
     * @return bool             Boolean indicating if price exists
     * @return uint256          Price of asset pair to 18 decimal precision (if exists, otherwise 0)
     */
    function _getPriceFromAdapters(
        address _assetOne,
        address _assetTwo
    )
        internal
        view
        returns (bool, uint256)
    {
        for (uint256 i = 0; i < adapters.length; i++) {
            (bool priceFound, uint256 price) = IOracleAdapter(adapters[i]).getPrice(_assetOne, _assetTwo);

            if (priceFound) {
                return (priceFound, price);
            }
        }

        return (false, 0);
    }
}
