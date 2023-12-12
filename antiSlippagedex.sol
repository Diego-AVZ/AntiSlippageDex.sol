//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

contract antiSlippage {
    // Es un DEX que permite realizar grandes ventas/compras con menor slippage
    // Ej: Una whale coloca su orden de Venta o de Compra de un token 
    // y selecciona:
    //              > Tokens de cambio: (quiere vender wBTC y selecciona que quiere recibir USDC y DAI)
    //              > Rango de precios de compra o venta
    //              > Rango temporal

    struct sellOrder {
        address whale;
        bool active;
        IERC20 sellToken;
        uint amount;
        uint priceUp;
        uint priceDo;
        uint lastDate;
        uint16 orderId;
    }

    uint16 sellOrderNum;

    sellOrder[] sellOrders;

    function placeSellOrder (address token, uint iamount, uint priceUp, uint priceDo, uint lastDate) public {
        uint16 id = sellOrderNum + 1;
        IERC20 tokenA = IERC20(token);
        sellOrder memory newSellOrder = sellOrder(msg.sender, true, tokenA, iamount, priceUp, priceDo, lastDate, id);
        sellOrders.push(newSellOrder);
        require(tokenA.approve(address(this), iamount));
        require(tokenA.transferFrom(msg.sender, address(this), iamount));
    }

   function buyTheSellOrder (uint amountUsd, uint16 orderId) public {
        uint i = findOrder(orderId);
        IERC20 usd = IERC20(0x71041dddaE2D69b2f1897eE142fbBb92d2892B30);
        IERC20 tokenA = IERC20(sellOrders[i].sellToken);
        address whale = sellOrders[i].whale;

        require(usd.approve(address(this), amountUsd));
        require(usd.transferFrom(msg.sender, whale, amountUsd));

        uint amountBuy = amountUsd / (uint(getPrice()) - (uint(getPrice()) * 4) / 1000);

        tokenA.transferFrom(address(this), msg.sender, amountBuy);
   }

   function findOrder (uint16 orderId) public view returns(uint){

        for(uint i = 0; i < sellOrders.length; i++){
            if (sellOrders[i].orderId == orderId) {
                return(i);
            }
        }

        revert("Not Found");
   }

   // PRICES _________________________________________________________________________

    AggregatorV2V3Interface internal dataFeed;
    AggregatorV2V3Interface internal sequencerUptimeFeed;

    uint256 private constant GRACE_PERIOD_TIME = 3600;

    error SequencerDown();
    error GracePeriodNotOver();

    constructor() {
        dataFeed = AggregatorV2V3Interface(0x71041dddaE2D69b2f1897eE142fbBb92d2892B30);
        sequencerUptimeFeed = AggregatorV2V3Interface(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433);
    }

    function getPrice() public view returns (int) {
        
        (,int256 answer,uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }

        (,int data,,,) = dataFeed.latestRoundData();

        return data;
    }
    // \PRICES _________________________________________________________________________________________

}



