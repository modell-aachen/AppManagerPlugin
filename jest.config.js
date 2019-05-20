module.exports = {
    moduleFileExtensions: [
        'js',
        'jsx',
        'json',
        'vue',
    ],
    transform: {
        '.*\\.(vue)$': 'vue-jest',
        '.+\\.(css|styl|less|sass|scss|svg|png|jpg|ttf|woff|woff2)$': 'jest-transform-stub',
        '^.+\\.jsx?$': 'babel-jest',
    },
    moduleNameMapper: {
        '^@/(.*)$': '<rootDir>/dev/$1',
        '\\.(css|less)$': 'identity-obj-proxy',
    },
    testMatch: [
        '**/frontend-tests/**/*.spec.(js|jsx|ts|tsx)|**/__tests__/*.(js|jsx|ts|tsx)',
    ],
    transformIgnorePatterns: [
        '/node_modules/(?!(vue-timers)/)',
    ],
    collectCoverageFrom: [
        'dev/**/*.{js,vue}',
        '!**/node_modules/**',
    ],
    coverageReporters: ['lcov', 'text-summary'],
    testURL: 'http://localhost/',
};
