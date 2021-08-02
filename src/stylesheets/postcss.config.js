module.exports = (ctx) => ({
  plugins: {
    autoprefixer: true,
    cssnano: {
      // refer to https://cssnano.co/docs/optimisations to understand this preset
      preset: [
        'default',
        {
          discardComments: { exclude: true }, // comments are currently aimed at the user, so keep them
          minifySelectors: { exclude: true }, // replaced by ./lib/postcss-minify-selectors.js
          minifyFontValues: { exclude: true }, // switches to numeric font weights, which make the stylesheet less extensible
          mergeRules: { exclude: true }, // TODO reenable; currently causes non-functional differences in output
          uniqueSelectors: { exclude: true }, // reorders selectors, which doesn't improve minification
          cssDeclarationSorter: { exclude: true }, // reorders properties, which doesn't improve minification
        },
      ]
    },
    './lib/postcss-minify-selectors.js': true,
    './lib/postcss-rule-per-line.js': true,
  }
})
