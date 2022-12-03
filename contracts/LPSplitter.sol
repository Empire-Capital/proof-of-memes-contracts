//SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.14;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IRouter {
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/// @title LPSplitterPoM: Splits LP fees from PoM DEX, buys back POMG token and burns
/// @author Empire Capital (Splnty, Tranquil Flow)
contract LPSplitter is Ownable {
    IRouter public router;
    address public tokenBuying;
    address public receiver;
    address WPOM = 0xC84D8d03aA41EF941721A4D77b24bB44D7C7Ac55;

    struct LpList {
        address lpAddress;  // Contract Address of the LP token
        bool token0fee;     // True = token0 in LP has fee on transfer
        bool token1fee;     // True = token1 in LP has fee on transfer
    }

    LpList[] public list;

    constructor() {
        router = IRouter(0x5322d6eD110c2990813E8168ae882112E64370Ec);
        tokenBuying = address(0x8BB07ad76ADdE952e83f2876c9bDeA9cc5B3a51E);
        receiver = 0x000000000000000000000000000000000000dEaD;
    }

    function process() external {
        // Unwrap LPs and sell for tokenBuying
        for(uint i = 0; i < list.length; i++) {
            unwrap(i);
            sellTokensForWPOM(i);
        }
        
        buybackAndBurn();
    }

    function unwrap(uint lpId) public {
        address liqAddress = list[lpId].lpAddress;
        uint lpAmount = IERC20(liqAddress).balanceOf(address(this));

        address token0 = IPair(liqAddress).token0();
        address token1 = IPair(liqAddress).token1();

        IERC20(liqAddress).approve(address(router), type(uint256).max);

        router.removeLiquidity(
            address(token0),
            address(token1),
            lpAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function sellTokensForWPOM(uint lpId) public {
        address liqAddress = list[lpId].lpAddress;
        address token0 = IPair(liqAddress).token0();
        address token1 = IPair(liqAddress).token1();

        IERC20(token0).approve(address(router), type(uint256).max);
        IERC20(token1).approve(address(router), type(uint256).max);
        IERC20(WPOM).approve(address(router), type(uint256).max);

        if(token0 != WPOM) {
            //swap token removed into WPOM
            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = WPOM; 

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(token0).balanceOf(address(this)),
                0,
                path,
                address(this),
                block.timestamp + 20
            );
        }

        if(token1 != WPOM) {
            //swap token removed into WPOM
            address[] memory path2 = new address[](2);
            path2[0] = token1;
            path2[1] = WPOM; 

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                IERC20(token1).balanceOf(address(this)),
                0,
                path2,
                address(this),
                block.timestamp + 20
            );
        }
    }

    function buybackAndBurn() public {
        //buyback and burn token with WPOM balance
        address[] memory path3 = new address[](2);
        path3[0] = WPOM;
        path3[1] = tokenBuying;

         router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            IERC20(WPOM).balanceOf(address(this)),
            0,
            path3,
            receiver,
            block.timestamp
        ); 
    }

    function addLp(address _lpAddress, bool _token0fee, bool _token1fee) external onlyOwner {
        list.push(LpList({
            lpAddress: _lpAddress,
            token0fee: _token0fee,
            token1fee: _token1fee
        }));
    }

    function removeLp(uint index) external onlyOwner {
        list[index] = list[list.length - 1];
        list.pop();
    }

    function changeSettings(
        address _tokenBuying,
        address _receiver,
        address _router
        ) external onlyOwner {
        tokenBuying = _tokenBuying;
        receiver = _receiver;
        router = IRouter(_router);
    }

    function recover(address token) external onlyOwner {
        if (token == 0x0000000000000000000000000000000000000000) {
            payable(msg.sender).call{value: address(this).balance}("");
        } else {
            IERC20 Token = IERC20(token);
            Token.transfer(msg.sender, Token.balanceOf(address(this)));
        }
    }

}