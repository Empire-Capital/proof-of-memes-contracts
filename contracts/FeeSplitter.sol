// function _mintFee(uint112 _reserve0, uint112 _reserve1)
//     private
//     returns (bool feeOn)
// {
//     address feeTo = IEmpireFactory(factory).feeTo();
//     feeOn = feeTo != address(0);
//     uint256 _kLast = kLast; // gas savings
//     if (feeOn) {
//         if (_kLast != 0) {
//             uint256 rootK = uint256(_reserve0).mul(_reserve1).sqrt();
//             uint256 rootKLast = _kLast.sqrt();
//             if (rootK > rootKLast) {
//                 uint256 numerator = totalSupply.mul(rootK.sub(rootKLast));
//                 uint256 denominator = rootK.mul(5).add(rootKLast);
//                 uint256 liquidity = numerator / denominator;
//                 if (liquidity > 0) _mint(feeTo, liquidity);
//             }
//         }
//     } else if (_kLast != 0) {
//         kLast = 0;
//     }
// }

// if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)

/* 
    Fee of 1/6th of the growth in sqrt(k)

    75% to liquidity providers and 
    25% sent to a contract for buybacks and burns of POMG (the governance token)

*/


