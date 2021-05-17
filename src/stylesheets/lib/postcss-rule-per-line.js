'use strict'

/**
 * Makes the minified stylesheet more readable by putting each rule on its own line and adding a trailing newline.
 */
module.exports = (opts) => {
  return {
    postcssPlugin: 'postcss-rule-per-line',
    OnceExit (root) {
      root.walk((node) => {
        if (node.type.endsWith('rule') && node.prev()) node.raws.before = '\n'
      })
      root.raws.after = '\n'
    },
  }
}

module.exports.postcss = true
