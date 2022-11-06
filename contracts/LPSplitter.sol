//SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.14;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
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

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
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

contract LPSplitter is Ownable {
    IRouter public router;
    address public lp;
    address public tokenA;
    address public tokenB;
    address public tokenSelling;
    address public tokenBuying;
    address public tokenBuybacking;
    address public tokenReceiver;

    constructor() {
        router = IRouter(0x0);
        lp = 0x0;
        tokenA = 0x0;
        tokenB = 0x0;
        tokenSelling = 0x0;
        tokenBuying = 0x0;
        tokenBuybacking = 0x0;
        tokenReceiver = 0x0;
    }

    function buybackAndBurn() external onlyOwner {
        uint lpAmount = IERC20(lp).balanceOf(address.this);
        address[] memory path = new address[](2);

        // Unwrap the LP token
        IERC20(lp).approve(address(router), lpAmount);
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            lpAmount,
            0,
            0,
            address(this),
            block.timestamp + 50
        );

        // Swap token for the other in the pair
        path[0] = address(tokenSelling);
        path[1] = address(tokenBuying);
        router.swapExactTokensForTokens(
            IERC20(tokenSelling).balanceOf(address.this),
            0,
            path,
            address(this),
            block.timestamp
        )[0];

        // Buyback token and burn them
        path[0] = address(tokenBuying);
        path[1] = address(tokenBuybacking);
        router.swapExactTokensForTokens(
            IERC20(tokenBuying).balanceOf(address.this),
            0,
            path,
            0x0, // Sends tokens to null address (0x0000000000000000000000000000000000000000)
            block.timestamp
        )[0];

    }

    function changeLP(
        address _lp,
        address _tokenA,
        address _tokenB
        ) external onlyOwner {
        lp = _lp;
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function changeSettings(
        address _tokenSelling,
        address _tokenBuying,
        address _tokenBuybacking,
        address _tokenReceiver
        ) external onlyOwner {
        tokenSelling = _tokenSelling;
        tokenBuying = _tokenBuying;
        tokenBuybacking = _tokenBuybacking;
        tokenReceiver = _tokenReceiver;
    }

}