const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');

module.exports = {
	entry: {
		index: './src/pages/login/index.tsx',
		stats: './src/pages/stats/index.tsx',
	},
	resolve: {
		extensions: ['.ts', '.tsx'],
	},
	module: {
		rules: [
			{ test: /\.ts|\.tsx/, use: 'swc-loader' }
		]
	},
	output: {
		filename: '[name].js',
		path: path.resolve(__dirname, 'dist'),
	},
	plugins: [
		new HtmlWebpackPlugin({
			filename: 'login.html',
			template: './html/login.html',
			chunks: ['index'],
		}),
		new HtmlWebpackPlugin({
			filename: 'stats.html',
			template: './html/stats.html',
			chunks: ['stats'],
		})
	]
};
