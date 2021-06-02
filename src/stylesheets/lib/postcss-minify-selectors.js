'use strict'

const selectorParser = require('postcss-selector-parser')

/**
 * Replaces the official postcss-minify-selectors plugin with a simpler implementation.
 *
 * The official plugin sorts the selectors and mangles pseudo-elements.
 * This simpler plugin only removes space characters and unnecessary quotes.
 */
module.exports = (opts) => {
  return {
    postcssPlugin: 'postcss-minify-selectors',
    Rule (rule) {
      rule.selector = selectorParser((selectors) => {
        selectors.walkAttributes((attr) => {
          if (attr.value) attr.raws.value = attr.getQuotedValue({ smart: true })
        })
      }).processSync(rule.selector, { lossless: false })
    },
  }
}

module.exports.postcss = true
