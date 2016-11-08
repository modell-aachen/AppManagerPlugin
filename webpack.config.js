var path = require('path')
var projectRoot = path.resolve(__dirname);
var webpack = require('webpack')

module.exports = {
  babel: {
    presets: ['es2015','stage-2']
  },
  eslint: {
    configFile: projectRoot + '/.eslintrc'
  },
  entry: {
    app: './dev/main.js'
  },
  output: {
    path: path.join(__dirname, 'pub/System/AppManagerPlugin'),
    filename: 'appmanager.js'
  },
  module: {
    loaders: [
      {
        enforce: "pre",
        test: /\.vue$/,
        loader: "eslint-loader",
        include: [
          projectRoot + '/dev',
          projectRoot + '/tests'
        ]
      },
      {
        test: /\.vue$/,
        loader: 'vue'
      },
      {
        test: /\.js$/,
        loader: 'babel',
        include: [
          projectRoot + '/dev',
          projectRoot + '/node_modules/vue-select/',
          projectRoot + '/tests'        ]
      },
      {
        test: /\.json$/,
        loader: 'json'
      },
      {
        test: /\.html$/,
        loader: 'vue-html'
      },
      {
        test: /\.css$/,
        loader: 'style-loader!css-loader'
      },
      {
        test: /\.less$/,
        loader: 'style-loader!less-loader'
      },
      {
        test: /\.(woff2?|eot|ttf|otf|svg)(\?.*)?$/,
        loader: 'url'
      }
    ]
  },
  vue: {
    loaders: {
      js: 'isparta'
    },
  plugins: [
  new webpack.optimize.UglifyJsPlugin({
      compress: false,
      mangle: false
    })
  ]
}
}
