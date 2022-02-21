// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.17 <0.8.11;

import "./ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//This contract is used only for a single game at a time. If in the case of multiple games, will need another contract to provide a control interface with additional signifiers to distinguish games.
contract DappBet is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    //ownership
    address public contractOwner; 

    //structs 
    struct Game {
        string teamA;
        string teamB;
        uint betStart;//Bet started after the time.
        uint betEnd; //Nobody could bet after the time.
        uint oddsA;
        uint oddsB;
        uint oddsDraw;
        uint scoreA; //Game results will need to be entered by game owner after the betEnd, and will then trigger prize distribution.
        uint scoreB;
    }

    struct Bet { 
        address user;
        uint stakeA; //amount bet on teamA
        uint stakeB;
        uint stakeDraw;
    }

    //variables, arrays and mappings
    //-control variables
    IERC20 internal token = IERC20(0xCa03AF1ffF3bc44a9E378eEE3E53d977F2cf2A88); //Using UHW address on BSC testnet as the TEST TOKEN for the bet.
    uint public betMin = 0; //minimum amount of each bet.
    //uint public betMax = 1000000; 
    //uint public betNumberMax = 1; //maximum number of times each person can bet in one particular game. Default value 1 bet per game per person.

    //-stats variables
    //uint public totalUsers; //total number of users for the CURRENT game. This variable is declared for temporary value holding, and should be calculated with a loop function to update before use. 
                            //Intentionally not definded in the game struct to help save Gas.
    uint public totalMoneyA;
    uint public totalMoneyB;
    uint public totalMoneyDraw;

    //-other variables and arrays
    Game public game; //This a variable in this single-game case, Not an array.
    Bet[] public bets;


    //events
    event NewBet (
        address user,
        uint stakeA, //amount bet on teamA
        uint stakeB,
        uint stakeDraw
    );


    //constructor
    constructor() payable { //IS PAYABLE NECESSARY?
        contractOwner = msg.sender;
        //game = Game("PSG","Real Madrid",0,1644953400,20300,36800,37900,0,0); //Initialize with the PSG@Real Madrid game at 3:00 pm EST on February 15, 2022. The bet end Unix time (2:30 pm EST) is 30 minutes before game.
    } //Remember to divide by 10000 for Odds to keep it int->actual dec

    /*Function scopes note
        public   - all can access
        external - Cannot be accessed internally, only externally
        internal - only this contract and contracts deriving from it can access
        private  - can be accessed only from this contract
    */

    //functions-bet-starting
    //function transferOwnership () private onlyOwner { }
    function getGameInfoAll () external view returns (string memory, string memory, uint, uint, uint, uint, uint, uint, uint) {
        //-uint totalBetsNumber = bets.length;
        return (game.teamA, game.teamB, game.betStart, game.betEnd, game.oddsA, game.oddsB, game.oddsDraw, game.scoreA, game.scoreB);
    }

    function setGameInfo (string memory _teamA, string memory _teamB, uint _betStart, uint _betEnd) external onlyOwner {
        //time require
        game.teamA = _teamA;
        game.teamB = _teamB;
        game.betStart = _betStart;
        game.betEnd = _betEnd;
    }

    function setGameOdds (uint _oddsA, uint _oddsB, uint _oddsDraw) external onlyOwner {
        //time require
        game.oddsA = _oddsA;
        game.oddsB = _oddsB;
        game.oddsDraw = _oddsDraw;
    }

    function setGameScore (uint _scoreA, uint _scoreB) external onlyOwner {  //This function will be refactored as an Oracle in the future versions.
        //time require
        game.scoreA = _scoreA;
        game.scoreB = _scoreB;
    }


    //functions-bet-runtime
    function toBet (uint _stakeA, uint _stakeB, uint _stakeDraw) external {
        //time require
        //-require (msg.sender != contractOwner, "Error: Bookmaker not allowed to bet.");
        require (_stakeA >= betMin, "Error: The minimum bet is  + betMin + tokens.");
        require (_stakeB >= betMin, "Error: The minimum bet is  + betMin + tokens.");
        require (_stakeDraw >= betMin, "Error: The minimum bet is  + betMin + tokens.");
        uint stakeTotal = _stakeA + _stakeB + _stakeDraw;
        //-bool isSuccessChargeFromUser;
        //uint erc20balance = token.balanceOf(address(this)); //Get THIS CONTRACT token balance from the given token contract.
        //require (stakeTotal <= erc20balance, "Error: Token balance too low.");
        
        //Approve the allowance
        token.safeIncreaseAllowance(address(this),stakeTotal);
        //Charge the money
          token.safeTransferFrom(msg.sender, address(this), stakeTotal);
        //-if (isSuccessChargeFromUser == true) {
            //Place the bet
            bets.push(Bet(msg.sender, _stakeA, _stakeB, _stakeDraw));
            totalMoneyA = totalMoneyA.add(_stakeA);
            totalMoneyB = totalMoneyB.add(_stakeB);
            totalMoneyDraw = totalMoneyDraw.add(_stakeDraw);
            if(totalMoneyA*totalMoneyB*totalMoneyDraw != 0) { updateStats(); } //Need subtotals not zero to update the Odds.
            emit NewBet(msg.sender, _stakeA, _stakeB, _stakeDraw);
        //} 
        //else {
        //-    return ("Error: Bet stake transfer fail.");
        //} 
    }

    /*/Calculate the odds ratio
    function updateOdds (uint totalMoneyA, uint totalMoneyB, uint totalMoneyDraw) internal { //Will need to return both decimal and fractional odds values in the next version.
        uint totalMoney = totalMoneyA.add(totalMoneyB.add(totalMoneyDraw));
        oddsA = totalMoney.div(totalMoneyA);
        oddsB = totalMoney.div(totalMoneyB);
        oddsDraw = totalMoney.div(totalMoneyDraw);
    } */

    function updateStats() internal  {
        uint totalMoney = totalMoneyA.add(totalMoneyB.add(totalMoneyDraw));
        game.oddsA = totalMoney.div(totalMoneyA);
        game.oddsB = totalMoney.div(totalMoneyB);
        game.oddsDraw = totalMoney.div(totalMoneyDraw);
    }

    /*function payStakeLoop(string memory _teamWon) public payable onlyOwner returns (bool) {
        for (uint i = 0; i < bets.length; i++) {
            address _user = bets[i].user;
            uint _stakeWon = bets[i].stakeA;
        }
    }*/

    //functions-bet-ending
    function distributeStake (uint _scoreA, uint _scoreB) external returns (bool) { //WILL NEED TO BE AUTO-TRIGGERED AFTER A GIVEN TIME IN LATER VERSIONS.
        if 
        (_scoreA > _scoreB) {
            //teamA won payStakeLoop("stakeA");
            for (uint i = 0; i < bets.length; i++) {
                token.safeTransfer(bets[i].user, bets[i].stakeA.mul(game.oddsA).div(10000));
            }
        } else if 
        (_scoreA < _scoreB) {
            //teamB won  payStakeLoop("stakeB");
            for (uint i = 0; i < bets.length; i++) {
                token.safeTransfer(bets[i].user, bets[i].stakeB.mul(game.oddsB).div(10000));
            }
        } else {
            //draw  payStakeLoop("stakeDraw");
            for (uint i = 0; i < bets.length; i++) {
                token.safeTransfer(bets[i].user, 88); //bets[i].stakeDraw.mul(game.oddsDraw).div(10000));
            }
        }
        return true;
    }


}
