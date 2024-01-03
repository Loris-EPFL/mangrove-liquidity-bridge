// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;
import "@mgv-strats/src/strategies/offer_maker/abstract/Direct.sol";
import "@mgv-strats/src/strategies/routers/SimpleRouter.sol";
import "@mgv/src/periphery/MgvReader.sol";
import {MgvReader, toOLKey, Market} from "@mgv/src/periphery/MgvReader.sol";
import {MgvLib, OLKey} from "@mgv/src/core/MgvLib.sol";
import {TickLib} from "@mgv/lib/core/TickLib.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import "@prb/math/casting/Uint256.sol";

// __lastLook__(order);
//  --> Invoke hook that implements a last look check during execution - it may renege on trade by reverting.
//   * get spot price, immediate fails if price + fees is not better than current price
//   *  execute the swap, then fails if not enough outbound token
// __put__ :
// Invoke hook to put the inbound token, which are brought by the taker, into a specific reserve.
// __get__ :
// Invoke hook to fetch the outbound token, which are promised to the taker, from a specific reserve.

contract LiquidityBridge is Direct {
    IERC20 public immutable BASE;
    IERC20 public immutable QUOTE;
    bool isDeployed = false;
    uint tickSpacing = 1;

    // Defined by the previous things.
    OLKey public olKeyB; //(base, quote)
    OLKey public olKeyQ; //(quote, base)

    ERC20Normalizer private immutable N;

    UD60x18 private quoteAmount;
    UD60x18 private spreadRatio;
    IDexLogic private dex;
    uint private bidId;
    uint private askId;

    constructor(
        IMangrove mgv,
        IERC20 base,
        IERC20 quote,
        UD60x18 quoteAmount_,
        UD60x18 spreadRatio_,
        address dexLogic,
        address admin
    ) Direct(mgv, NO_ROUTER, admin) {
        // SimpleRouter takes promised liquidity from admin's address (wallet)
        BASE = base;
        QUOTE = quote;

        olKeyB = toOLKey(Market({
            tkn0: address(BASE), 
            tkn1: address(QUOTE), 
            tickSpacing: tickSpacing
        }));

        olKeyQ = toOLKey(Market({
            tkn0: address(QUOTE), 
            tkn1: address(BASE), 
            tickSpacing: tickSpacing
        }));

        N = new ERC20Normalizer();
        quoteAmount = quoteAmount_;
        setSpreadRatio(spreadRatio_);
        dex = IDexLogic(dexLogic);

        AbstractRouter router_ = new SimpleRouter();
        setRouter(router_);
        // adding `this` to the allowed makers of `router_` to pull/push liquidity
        // Note: `reserve(admin)` needs to approve `this.router()` for base token transfer
        router_.bind(address(this));
        router_.setAdmin(admin);
        setAdmin(admin);
    }

    /// @notice This enables the admin to withdraw tokens from the contract. Notice that only the admin can call this.
    /// @param token The token to be withdrawn
    /// @param amount The amount to be withdrawn
    /// @param to The address the amount should be transferred to.
    /// @return success true if transfer was successful; otherwise, false.
    function withdrawToken(
        address token,
        uint amount,
        address to
    ) external onlyAdmin returns (bool success) {
        return TransferLib.transferToken(IERC20(token), to, amount);
    }

    /// @notice This enables the admin to withdraw native tokens from the contract. Notice that only the admin can call this.
    /// @param amount The amount to be withdrawn
    /// @param to The address the amount should be transferred to.
    /// @return success true if transfer was successful; otherwise, false.
    function withdrawNative(
        uint amount,
        address to
    ) external onlyAdmin returns (bool success) {
        (success, ) = to.call{value: amount}("");
    }

    function withdrawBalance() public onlyAdmin {
        uint balance = MGV.balanceOf(address(this));

        if (balance > 0) {
            require(MGV.withdraw(balance), "LiquidityBridge/withdrawFail");
            (bool noRevert, ) = admin().call{value: balance}("");
            require(noRevert, "LiquidityBridge/weiTransferFail");
        }
    }

    /// @notice Sets the underlying bridged dex where the liquidity will be sourced from
    function setDex(IDexLogic dexLogic) external onlyAdmin {
        dex = IDexLogic(dexLogic);
    }

    /// @notice Sets the amount of quote tokens targeted for each offer
    function setQuoteAmount(UD60x18 quoteAmount_) external onlyAdmin {
        quoteAmount = quoteAmount_;
    }

    /// @notice Sets the spread used to post the offers (spotPrice x spreadRatio -> for the ask, spotPrice / spreadRatio -> for the bid )
    /// @param spreadGeo_ the ratio of BASE/QUOTE price. Should be > 1
    function setSpreadRatio(UD60x18 spreadGeo_) public onlyAdmin {
        require(ud(1e18) < spreadGeo_, "LiquidityBridge/ratioTooSmall");
        spreadRatio = spreadGeo_;
    }

    function newLiquidityOffers() external payable onlyAdmin returns (uint, uint) {
        // there is a cost of being paternalistic here, we read MGV storage
        // an offer can be in 4 states:
        // - not on mangrove (never has been)
        // - on an offer list (isLive)
        // - not on an offer list (!isLive) (and can be deprovisioned or not)
        // MGV.retractOffer(..., deprovision:bool)
        // deprovisioning an offer (via MGV.retractOffer) credits maker balance on Mangrove (no native token transfer)
        // if maker wishes to retrieve native tokens it should call MGV.withdraw (and have a positive balance)
        
        //TOFIX: this
        require(!isDeployed);
        // FIXME the above requirements are not enough because offerId might be live on another base, stable market
        UD60x18 midPrice = dex.currentPrice(address(BASE), address(QUOTE));
        uint notNormWantAmount;
        uint notNormGiveAmount;

        notNormWantAmount = N.denormalize(QUOTE, quoteAmount.intoUint256());
        notNormGiveAmount = N.denormalize(
            BASE,
            quoteAmount.div(midPrice).div(spreadRatio).intoUint256()
        );

        Tick tick = TickLib.tickFromVolumes(notNormWantAmount, notNormGiveAmount);
        
        (askId, ) = _newOffer(
            OfferArgs({
            olKey: olKeyB, 
            tick: tick, 
            gives: notNormGiveAmount, 
            gasreq: 400000, 
            gasprice: 0, 
            fund: msg.value, 
            noRevert: false
            })
        );

        notNormWantAmount = N.denormalize(
            BASE,
            quoteAmount.div(midPrice).mul(spreadRatio).intoUint256()
        );
        notNormGiveAmount = N.denormalize(QUOTE, quoteAmount.intoUint256());
        
        tick = TickLib.tickFromVolumes(notNormWantAmount, notNormGiveAmount);
        // no need to fund this second call for provision
        // since the above call should be enough
        (bidId, ) = _newOffer(
            OfferArgs({
            olKey: olKeyQ, 
            tick: tick, 
            gives: notNormGiveAmount, 
            gasreq: 400000, 
            gasprice: 0, 
            fund: 0, 
            noRevert: false
            })
        );
        isDeployed = true;
        return (askId, bidId);
    }

    function refreshOffers() public adminOrCaller(address(MGV)) {
        UD60x18 midPrice = dex.currentPrice(address(BASE), address(QUOTE));

        uint notNormWantAmount;
        uint notNormGiveAmount;

        notNormWantAmount = N.denormalize(QUOTE, quoteAmount.intoUint256());
        notNormGiveAmount = N.denormalize(
            BASE,
            quoteAmount.div(midPrice).div(spreadRatio).intoUint256()
        );

        Tick tick = TickLib.tickFromVolumes(notNormWantAmount, notNormGiveAmount);

        super._updateOffer(
            OfferArgs({
                olKey: olKeyB, 
                tick: tick, 
                gives: notNormGiveAmount, 
                gasreq: 400000, 
                gasprice: 0, 
                fund: 0, 
                noRevert: false}),
            askId
        );

        notNormWantAmount = N.denormalize(
            BASE,
            quoteAmount.div(midPrice).mul(spreadRatio).intoUint256()
        );

        notNormGiveAmount = N.denormalize(QUOTE, quoteAmount.intoUint256());
        tick = TickLib.tickFromVolumes(notNormWantAmount, notNormGiveAmount);
        
        super._updateOffer(
            OfferArgs({
                olKey: olKeyQ, 
                tick: tick, 
                gives: notNormGiveAmount, 
                gasreq: 400000, 
                gasprice: 0, 
                fund: 0, 
                noRevert: false}),
            bidId
        );
    }

    function __posthookSuccess__(
        MgvLib.SingleOrder calldata order,
        bytes32 makerData
    ) internal override returns (bytes32) {
        // reposts residual if any (conservative hook)
        bytes32 repost_status = super.__posthookSuccess__(order, makerData);

        // write here what you want to do if not `reposted`
        // reasons for not ok are:
        // - residual below density (dust)
        // - not enough provision
        // - offer list is closed (governance call)

        if (repost_status == "posthook/reposted") {} else {
            // repost failed or offer was entirely taken
            refreshOffers();
            return "posthook/offersRefreshed";
        }
    }

    function retractOffer(
        OLKey memory olKey,
        uint offerId,
        bool deprovision
    ) public adminOrCaller(address(MGV)) returns (uint freeWei) {
        return _retractOffer(olKey, offerId, deprovision);
    }

    function retractOffers(bool deprovision) external {
        uint freeWei = retractOffer({
            olKey: olKeyB,
            offerId: askId,
            deprovision: deprovision
        });

        freeWei += retractOffer({
            olKey: olKeyQ,
            offerId: bidId,
            deprovision: deprovision
        });

        if (freeWei > 0) {
            require(MGV.withdraw(freeWei), "LiquidityBridge/withdrawFail");
            // sending native tokens to `msg.sender` prevents reentrancy issues
            // (the context call of `retractOffer` could be coming from `makerExecute` and a different recipient of transfer than `msg.sender` could use this call to make offer fail)
            (bool noRevert, ) = admin().call{value: freeWei}("");
            require(noRevert, "LiquidityBridge/weiTransferFail");
        }
    }

    function __lastLook__(
        MgvLib.SingleOrder calldata order
    ) internal override returns (bytes32) {
        if (order.takerWants == 0) {
            return "TakerWantsZero";
        }

        dex.swap(
            order.olKey.inbound_tkn,
            order.olKey.outbound_tkn,
            ud(N.normalize(IERC20(order.olKey.inbound_tkn), order.takerGives)),    
            ud(N.normalize(IERC20(order.olKey.outbound_tkn), order.takerWants))
        );
    }

    function __posthookFallback__(
        MgvLib.SingleOrder calldata order,
        MgvLib.OrderResult calldata
    ) internal override returns (bytes32) {
        refreshOffers();
        return "posthook/offersRefreshed";
    }

    function __activate__(IERC20 token) internal override {
        super.__activate__(token);
        token.approve(address(dex), type(uint256).max);
    }
}
