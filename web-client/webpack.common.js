const path = require("path");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const ForkTsCheckerWebpackPlugin = require('fork-ts-checker-webpack-plugin');

module.exports = {
	entry: {
		login: "./src/pages/login/index.tsx",
		stats: "./src/pages/stats/index.tsx",
	},
	resolve: {
		extensions: [".js", ".mjs", ".ts", ".tsx"],
	},
	module: {
		rules: [{ test: /\.ts|\.tsx/, use: "swc-loader" }],
	},
	output: {
		filename: "[name].js",
		path: path.resolve(__dirname, "dist"),
	},
	plugins: [
		new ForkTsCheckerWebpackPlugin(),
		new HtmlWebpackPlugin({
			filename: "login.html",
			template: "./html/login.html",
			chunks: ["login"],
		}),
		new HtmlWebpackPlugin({
			filename: "stats.html",
			template: "./html/stats.html",
			chunks: ["stats"],
		}),
	],
};
