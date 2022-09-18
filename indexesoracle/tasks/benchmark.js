const oracleAbi = require("../artifacts/contracts/PriceOracle.sol/PriceOracle.json").abi

const sleep = sec => new Promise(res => setTimeout(res, sec * 1000))

module.exports = providerApiKeys =>
  task("benchmark", "Benchmark test of feed price & get price call")
    .addParam('oracleAddr', 'Oracle contract address')
    .addParam('feedCount', 'Feed count')
    .setAction(async (args, { ethers }) => {
      console.log('Getting ready...')

      const provider = ethers.getDefaultProvider(3, providerApiKeys)
      const oracle = new ethers.Contract(args.oracleAddr, oracleAbi, provider)
      const users = await ethers.getSigners()
      const [ deployer ] = users

      const randomAddress = () =>
        ethers.utils.keccak256(
          ethers.utils.toUtf8Bytes(Math.random().toString()
        )).slice(0, 42)

      const randomPrice = () =>
        Math.random().toString()
          .slice(2)
          .concat(Math.random().toString().slice(2))
          .slice(2, 20)

      const feeds = Array(Number(args.feedCount)).fill(0).map(() => ({
        asset1: randomAddress(),
        asset2: randomAddress(),
        price: randomPrice(),
        decimals: 18
      }))

      let feedCounter = 0
      const duration = 60

      console.log('Benchmarking feeds...')

      feeds.forEach(feed => {
        oracle.connect(deployer)
          .feedPrice(feed.asset1, feed.asset2, feed.price, feed.decimals)
          .then(() => feedCounter++)
          .catch(() => {})
      })

      await sleep(duration)

      console.log(
        '{0} feeds out of {1} ({2} %) were successful in {3} sec.'
          .replace('{0}', feedCounter)
          .replace('{1}', feeds.length)
          .replace('{2}', Math.round(feedCounter * 100 / feeds.length))
          .replace('{3}', duration)
      )

      let priceCounter = 0

      console.log('Benchmarkig getting price...')

      feeds.forEach(feed => {
        oracle.getPrice(feed.asset1, feed.asset2)
          .then(() => priceCounter++)
          .catch(() => {})
      })

      await sleep(duration)

      console.log(
        '{0} prices out of {1} ({2} %) were successful in {3} sec.'
          .replace('{0}', priceCounter)
          .replace('{1}', feeds.length)
          .replace('{2}', Math.round(priceCounter * 100 / feeds.length))
          .replace('{3}', duration)
      )
    })
