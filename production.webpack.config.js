var baseConfig = require('./base.webpack.config.js');
var webpack = require('webpack');
var merge = require('webpack-merge');

module.exports = merge.smart(baseConfig, {
	plugins: [
		new webpack.optimize.UglifyJsPlugin({
			sourceMap: true
		}),
		new webpack.optimize.AggressiveMergingPlugin(),
		new webpack.DefinePlugin({
	      'process.env': {
	        NODE_ENV: '"production"'
	      }
	    })
	],
	//This is a workaround to reduce file size.
	//Remove this when https://github.com/webpack-contrib/css-loader/issues/454 is resolved
	node: {
	  Buffer: false
	}
});