// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.10;
import "@mgv-strats/src/strategies/offer_maker/abstract/Direct.sol";
import "@mgv-strats/src/strategies/routers/SimpleRouter.sol";
import {MgvLib, MgvStructs} from "@mgv/src/core/MgvLib.sol";
import {IDexLogic} from "src/DexLogic/IDexLogic.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import "@prb/math/casting/Uint256.sol";

// __lastLook__(order);
//  --> Invoke hook that implements a last look check during execution - it may renege on trade by reverting.
//   *  get spot price, immediate fails if price + fees is not better than current price
//   *  execute the swap, then fails if not enough outbound token
// __put__ :
// Invoke hook to put the inbound token, which are brought by the taker, into a specific reserve.
// __get__ :
// Invoke hook to fetch the outbound token, which are promised to the taker, from a specific reserve.

contract LiquidityBridge is Direct {
    IERC20 public immutable BASE;
    IERC20 public immutable QUOTE;
    ERC20Normalizer private immutable N;

    UD60x18 private quoteAmount;
    UD60x18 private spreadRatio;

    IDexLogic private dex;
    OfferDoublet[] private offersDoublet;
    uint public offersNumberVal;
    uint incrementValue;

    constructor(
        IMangrove mgv,
        IERC20 base,
        IERC20 quote,
        UD60x18 quoteAmount_,
        UD60x18 spreadRatio_,
        uint nbOffers, 
        uint incrementValueCon,
        address dexLogic,
        address admin
    ) Direct(mgv, NO_ROUTER, 400_000, admin) {
        // SimpleRouter takes promised liquidity from admin's address (wallet)
        BASE = base;
        QUOTE = quote;
        N = new ERC20Normalizer();
        quoteAmount = quoteAmount_;
        offersNumberVal = nbOffers;
        incrementValue = incrementValueCon;
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

    /// @notice Sets the increment for ratio
    function setIncrementValue(uint _incrementValue) external onlyAdmin {
        incrementValue = _incrementValue;
    }

    /// @notice Sets the spread used to post the offers (spotPrice x spreadRatio -> for the ask, spotPrice / spreadRatio -> for the bid )
    /// @param spreadGeo_ the ratio of BASE/QUOTE price. Should be > 1
    function setSpreadRatio(UD60x18 spreadGeo_) public onlyAdmin {
        require(ud(1e18) < spreadGeo_, "LiquidityBridge/ratioTooSmall");
        spreadRatio = spreadGeo_;
    }

    function deployMultiOffers(uint offersNumber, uint askPivotId,
        uint bidPivotId) public payable onlyAdmin returns (uint, uint) {
            require(incrementValue > 0, "Increment need to be non zero.");
            
            for (uint i = 0; i < offersNumber; i++) {  
                newLiquidityOffers(askPivotId, bidPivotId, 100 * (10 + i * incrementValue ) / 10 ); 
            }

        }

    struct OffersVariables {
        uint notNormWantAmount;
        uint notNormGiveAmount;
        uint bidId;
        uint askId;
        UD60x18 UdproportionValue;
        UD60x18 Ud100;
        UD60x18 Ud1000;
        UD60x18 UdPos;
    }

    struct OfferDoublet {
        uint askId;
        uint bidId;
    }

    // TODO : rename to newOffers
    function newLiquidityOffers(
        uint askPivotId,
        uint bidPivotId,
        uint proportionValue
    ) public payable onlyAdmin {
        // there is a cost of being paternalistic here, we read MGV storage
        // an offer can be in 4 states:
        // - not on mangrove (never has been)
        // - on an offer list (isLive)
        // - not on an offer list (!isLive) (and can be deprovisioned or not)
        // MGV.retractOffer(..., deprovision:bool)
        // deprovisioning an offer (via MGV.retractOffer) credits maker balance on Mangrove (no native token transfer)
        // if maker wishes to retrieve native tokens it should call MGV.withdraw (and have a positive balance)
        // FIXME: the above requirements are not enough because offerId might be live on another base, stable market
        require(proportionValue >= 100, "Increment value need to be superior or equal to 100.");
        UD60x18 midPrice = dex.currentPrice(address(BASE), address(QUOTE));
        
        OffersVariables memory offersVariables;
        offersVariables.UdproportionValue = PRBMathCastingUint256.intoUD60x18(proportionValue*1e18);
        offersVariables.Ud100 = PRBMathCastingUint256.intoUD60x18(100e18);
        offersVariables.Ud1000 = PRBMathCastingUint256.intoUD60x18(1000e18);
        offersVariables.UdPos = PRBMathCastingUint256.intoUD60x18((offersDoublet.length+1)*1e18); // 1 -> 1e18
        UD60x18 newQuoteAmount = quoteAmount.mul(offersVariables.UdproportionValue).div(offersVariables.Ud100);
        UD60x18 spreadMultiplier = (offersVariables.UdPos.add(offersVariables.Ud100)).div(offersVariables.Ud100);

        offersVariables.notNormWantAmount = N.denormalize(QUOTE, newQuoteAmount.intoUint256());
        offersVariables.notNormGiveAmount = N.denormalize(
        BASE,
        newQuoteAmount.div(midPrice).div(spreadRatio.mul(spreadMultiplier)).intoUint256()
        );
        // quoteAmount

        (offersVariables.askId, ) = _newOffer(
        OfferArgs({
            outbound_tkn: BASE,
            gives: offersVariables.notNormGiveAmount,
            inbound_tkn: QUOTE,
            wants: offersVariables.notNormWantAmount,
            gasreq: offerGasreq(),
            gasprice: 0,
            pivotId: askPivotId,
            fund: msg.value,
            noRevert: false
        }) 
        );
        
        offersVariables.notNormWantAmount = N.denormalize(          // we divide by 100 to have percent 
            BASE, newQuoteAmount.div(midPrice).mul(spreadRatio).mul(spreadMultiplier).intoUint256()
        );

        offersVariables.notNormGiveAmount = N.denormalize(QUOTE, newQuoteAmount.intoUint256());
        // no need to fund this second call for provision
        // since the above call should be enough
        (offersVariables.bidId, ) = _newOffer(
            OfferArgs({
                outbound_tkn: QUOTE,
                gives: offersVariables.notNormGiveAmount,
                inbound_tkn: BASE,
                wants: offersVariables.notNormWantAmount,
                gasreq: offerGasreq(),
                gasprice: 0,
                pivotId: bidPivotId,
                fund: 0,
                noRevert: false
            })
        );

        OfferDoublet memory newPair = OfferDoublet(offersVariables.askId, offersVariables.bidId);
        offersDoublet.push(newPair);
    }

    function findValueInOfferDoublet(uint targetId, uint binary) private view returns (uint) {
        if (binary == 0){
            for (uint i = 0; i < offersDoublet.length; i++) {
                if (offersDoublet[i].askId == targetId) {
                    return uint(i);
                }
            }
        } else {
            for (uint i = 0; i < offersDoublet.length; i++) {
                if (offersDoublet[i].bidId == targetId) {
                    return uint(i);
                }
            }
        }
        return 999999;
    }

    function refreshDoubleOffer(uint offerId, uint binary) public adminOrCaller(address(MGV)) {
        UD60x18 midPrice = dex.currentPrice(address(BASE), address(QUOTE));
        
        OffersVariables memory offersVariables;
        offersVariables.Ud100 = PRBMathCastingUint256.intoUD60x18(100*1e18);
        uint position = findValueInOfferDoublet(offerId, binary); // if binary == 0 is ask if 1 is bid
        require(position < 999999, "Position not found.");

        offersVariables.askId = offersDoublet[position].askId;
        offersVariables.bidId = offersDoublet[position].bidId;
        offersVariables.UdPos = PRBMathCastingUint256.intoUD60x18((position+1)*1e18);
        offersVariables.Ud1000 = PRBMathCastingUint256.intoUD60x18(1000e18);

        // position 

        uint proportionValue = 100 * (10 + position * incrementValue ) / 10 ;
        offersVariables.UdproportionValue = PRBMathCastingUint256.intoUD60x18(proportionValue*1e18);
        UD60x18 newQuoteAmount = quoteAmount.mul(offersVariables.UdproportionValue).div(offersVariables.Ud100);
        UD60x18 spreadMultiplier = (offersVariables.UdPos.add(offersVariables.Ud100)).div(offersVariables.Ud100);

        MgvStructs.OfferPacked askOffer = MGV.offers(
            address(BASE),
            address(QUOTE),
            offersVariables.askId
        );

        offersVariables.notNormWantAmount = N.denormalize(QUOTE, newQuoteAmount.intoUint256());
        offersVariables.notNormGiveAmount = N.denormalize(
            BASE,
            newQuoteAmount.div(midPrice).div(spreadRatio.mul(spreadMultiplier)).intoUint256()
        );
        super._updateOffer(
            OfferArgs({
                outbound_tkn: BASE,
                inbound_tkn: QUOTE,
                wants: offersVariables.notNormWantAmount,
                gives: offersVariables.notNormGiveAmount,
                gasreq: offerGasreq(),
                gasprice: 0,
                fund: 0,
                pivotId: askOffer.next(),
                noRevert: false
            }),
            offersVariables.askId
        );

        MgvStructs.OfferPacked bidOffer = MGV.offers(
            address(QUOTE),
            address(BASE),
            offersVariables.bidId
        );
        offersVariables.notNormWantAmount = N.denormalize(
            BASE,
            newQuoteAmount.div(midPrice).mul(spreadRatio.mul(spreadMultiplier)).intoUint256()
        );

        offersVariables.notNormGiveAmount = N.denormalize(QUOTE, newQuoteAmount.intoUint256());
        super._updateOffer(
            OfferArgs({
                outbound_tkn: QUOTE,
                inbound_tkn: BASE,
                wants: offersVariables.notNormWantAmount,
                gives: offersVariables.notNormGiveAmount,
                gasreq: offerGasreq(),
                gasprice: 0,
                pivotId: bidOffer.next(),
                fund: 0,
                noRevert: false
            }),
            offersVariables.bidId
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
            if (order.outbound_tkn == address(BASE)) // ask
                refreshDoubleOffer(order.offerId, 0);
            else {                          // bid
                refreshDoubleOffer(order.offerId, 1);
            }
            return "posthook/offersRefreshed";
        }
    }

    function retractOffer(
        IERC20 outbound_tkn,
        IERC20 inbound_tkn,
        uint offerId,
        bool deprovision
    ) public adminOrCaller(address(MGV)) returns (uint freeWei) {
        return _retractOffer(outbound_tkn, inbound_tkn, offerId, deprovision);
    }

    function retractOffers(bool deprovision) external {
        uint freeWei;

        for (uint i = offersDoublet.length; i > 0;) {  
            i--;
            freeWei += retractOffer({
            outbound_tkn: BASE,
            inbound_tkn: QUOTE,
            offerId: offersDoublet[i].askId,
            deprovision: deprovision
            });

            freeWei += retractOffer({
                outbound_tkn: QUOTE,
                inbound_tkn: BASE,
                offerId: offersDoublet[i].bidId,
                deprovision: deprovision
            });
            offersDoublet.pop();
        }


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
        if (order.wants == 0) {
            return "TakerWantsZero";
        }

        dex.swap(
            order.inbound_tkn,
            order.outbound_tkn,
            ud(N.normalize(IERC20(order.inbound_tkn), order.gives)),
            ud(N.normalize(IERC20(order.outbound_tkn), order.wants))
        );
    }

    function __posthookFallback__(
        MgvLib.SingleOrder calldata order,
        MgvLib.OrderResult calldata
    ) internal override returns (bytes32) {
        // order.offerId, I need to find symetrical
           
        if (order.outbound_tkn == address(BASE)) // ask
            refreshDoubleOffer(order.offerId, 0);
        else {                          // bid
            refreshDoubleOffer(order.offerId, 1);
        }
        return "posthook/offersRefreshed";
    }

    function __activate__(IERC20 token) internal override {
        super.__activate__(token);
        token.approve(address(dex), type(uint256).max);
    }
}
