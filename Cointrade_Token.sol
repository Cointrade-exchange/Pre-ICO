pragma solidity ^0.4.11;

import './MintableToken.sol';
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";

//For production, change all days to days
//Change and check days and discounts
contract Cointrade_Token is Ownable, usingOraclize {
    using SafeMath for uint256;

    // The token being sold
    MintableToken public token;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public PreICOStartTime;
    uint256 public PreICOEndTime;

    uint256 public hardCap = 212500000;

    // address where funds are collected
    address public wallet;

    // how many token units a buyer gets per wei
    uint256 public rate;
    uint256 public weiRaised;

    /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event newOraclizeQuery(string description);

    function Cointrade_Token (uint256 _rate, address _wallet) public {
        require(_rate > 0);
        require(_wallet != address(0));

        token = createTokenContract();

        rate = _rate;
        wallet = _wallet;
    }
    function startPreICO() onlyOwner public {
        require(PreICOStartTime == 0);
        PreICOStartTime = now;
        PreICOEndTime = PreICOStartTime + 20 days;
    }
    function stopPreICO() onlyOwner public {
        require(PreICOEndTime > now);
        PreICOEndTime = now;
    }

    // creates the token to be sold.
    // override this method to have crowdsale of a specific mintable token.
    function createTokenContract() internal returns (MintableToken) {
        return new MintableToken();
    }

    // fallback function can be used to buy tokens
    function () payable public {
        buyTokens(msg.sender);
    }

    //return token price in cents
    function getUSDPrice() public constant returns (uint256 cents_by_token) {
        return 20;
    }
    // string 123.45 to 12345 converter
    function stringFloatToUnsigned(string _s) payable returns (string) {
        bytes memory _new_s = new bytes(bytes(_s).length - 1);
        uint k = 0;

        for (uint i = 0; i < bytes(_s).length; i++) {
            if (bytes(_s)[i] == '.') { break; } // 1

            _new_s[k] = bytes(_s)[i];
            k++;
        }

        return string(_new_s);
    }
    // callback for oraclize 
    function __callback(bytes32 myid, string result) {
        if (msg.sender != oraclize_cbAddress()) throw;
        string memory converted = stringFloatToUnsigned(result);
        rate = parseInt(converted);
        rate = SafeMath.div(1000000000000000000, rate); // price for 1 `usd` in `wei` 
    }
    // price updater 
    function updatePrice() payable {
        oraclize_setProof(proofType_NONE);
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            oraclize_query("URL", "json(https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD).USD");
        }
    }
    // low level token purchase function
    function buyTokens(address beneficiary) public payable {
        require(beneficiary != address(0));
        require(validPurchase());

        updatePrice();

        uint256 _convert_rate = SafeMath.div(SafeMath.mul(rate, getUSDPrice()), 100);

        // calculate token amount to be created
        uint256 weiAmount = SafeMath.mul(msg.value, 10**uint256(token.decimals()));
        uint256 tokens = SafeMath.div(weiAmount, _convert_rate);
        require(tokens > 0);

        // update state
        weiRaised = SafeMath.add(weiRaised, msg.value);

        token.mint(beneficiary, tokens);
        TokenPurchase(msg.sender, beneficiary, msg.value, tokens);

        forwardFunds();
    }


    //to send tokens for bitcoin bakers and bounty
    function sendTokens(address _to, uint256 _amount) onlyOwner public {
        token.mint(_to, _amount);
    }
    //change owner for child contract
    function transferTokenOwnership(address _newOwner) onlyOwner public {
        token.transferOwnership(_newOwner);
    }

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(this.balance);
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool hardCapOk = token.totalSupply() <= SafeMath.mul(hardCap, 10**uint256(token.decimals()));
        bool withinPreICOPeriod = now >= PreICOStartTime && now <= PreICOEndTime;
        bool nonZeroPurchase = msg.value != 0;
        return hardCapOk && withinPreICOPeriod && nonZeroPurchase;
    }
}