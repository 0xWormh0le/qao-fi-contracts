module.exports = async ({getNamedAccounts, deployments}) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy('PriceOracle', {
    from: deployer,
    args: [
      '0xfe724a829fdf12f7012365db98730eee33742ea2', // ropsten usdc
      []
    ],
    log: true,
  });
};

module.exports.tags = ['PriceOracle'];
