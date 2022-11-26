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

/// @title LPSplitterPoM: Splits LP fees from PoM DEX, buys back POM token and burns
/// @author Empire Capital (Tranquil Flow)
contract LPSplitter is Ownable {
    IRouter public router;
    address public tokenBuying;
    bool public swapEnabled;
    address public receiver;

    struct LpList {
        address lpAddress;  // Contract Address of the LP token
        bool token0fee;     // True = token0 in LP has fee on transfer
        bool token1fee;     // True = token1 in LP has fee on transfer
    }

    LpList[] public list;

    constructor(address _router, address _tokenBuying) {
        router = IRouter(_router);
        tokenBuying = _tokenBuying;
        swapEnabled = true;
        receiver = 0x0000000000000000000000000000000000000000;
    }

    function process() external {
        for(uint i = 0; i < list.length; i++) {
            unwrapAndBuy1(i);
            unwrapAndBuy2(i);
        }
    }

    function unwrapAndBuy1(uint lpId) public {
        address liqAddress = list[lpId].lpAddress;
        uint lpAmount = IERC20(liqAddress).balanceOf(address(this));

        IERC20(liqAddress).approve(address(router), lpAmount);

        router.removeLiquidity(
            address(IPair(liqAddress).token0()),
            address(IPair(liqAddress).token1()),
            lpAmount,
            0,
            0,
            address(this),
            block.timestamp + 10
        );
    }

    function unwrapAndBuy2(uint lpId) public {
        address liqAddress = list[lpId].lpAddress;
        address token0 = IPair(liqAddress).token0();
        address token1 = IPair(liqAddress).token1();

        // Swap token0 into tokenBuying
        if(token0 != tokenBuying) {
            address[] memory path = new address[](2);
            path[0] = token0;
            path[1] = tokenBuying;
            uint swapAmount = IERC20(token0).balanceOf(address(this));
            IERC20(token0).approve(address(router), swapAmount);
            
            if(list[lpId].token0fee) {
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    swapAmount,
                    0,
                    path,
                    address(this),
                    block.timestamp + 10
                );
            } else {
                router.swapExactTokensForTokens(
                    swapAmount,
                    0,
                    path,
                    address(this),
                    block.timestamp + 10
                );  
            }  
        }

        // Swap token1 into tokenBuying
        if(token1 != tokenBuying) {
            address[] memory path2 = new address[](2);
            path2[0] = token1;
            path2[1] = tokenBuying;
            uint swapAmount = IERC20(token1).balanceOf(address(this));
            IERC20(token1).approve(address(router), swapAmount);
            
            if(list[lpId].token1fee) {
                router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    swapAmount,
                    0,
                    path2,
                    address(this),
                    block.timestamp + 10
                );
            } else {
                router.swapExactTokensForTokens(
                    swapAmount,
                    0,
                    path2,
                    address(this),
                    block.timestamp + 10
                );  
            }  
        }

        // // Transfer tokenBuying to receiver
        // IERC20(tokenBuying).transfer(receiver, IERC20(tokenBuying).balanceOf(address(this)));
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
        bool _swapEnabled
        ) external onlyOwner {
        tokenBuying = _tokenBuying;
        receiver = _receiver;
        swapEnabled = _swapEnabled;
    }

}