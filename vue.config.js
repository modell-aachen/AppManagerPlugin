const CompressionPlugin = require('compression-webpack-plugin');

const isProduction = () => process.env.NODE_ENV === 'production';

const plugins = [];
if(isProduction()) {
    plugins.push(new CompressionPlugin({
        include: [/\.(?:js|css)$/],
    }));
}
const pages = {
    'appmanager': {
        entry: 'dev/main',
    },
};

module.exports = {
    configureWebpack: {
        plugins: plugins,
        optimization: {
            splitChunks: false,
        },
        output: {
            filename: '[name].js',
        },
    },
    css: {
        extract: false
    },
    chainWebpack: config => {
        config.plugins.delete('hmr');
        for(const page in pages) {
            config.plugins.delete(`html-${page}`);
            config.plugins.delete(`preload-${page}`);
            config.plugins.delete(`prefetch-${page}`);
        }
    },
    productionSourceMap: true,
    outputDir: 'pub/System/AppManagerPlugin',
    publicPath: '/pub/System/AppManagerPlugin/',
    pages,
};
