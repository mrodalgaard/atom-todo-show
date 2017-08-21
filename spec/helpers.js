var cacheConfigSchema = undefined

exports.getConfigSchema = function getConfigSchema(callback) {
  if (cacheConfigSchema) return callback(cacheConfigSchema)
  atom.packages.activatePackage('todo-show').then( () => {
    cacheConfigSchema = atom.config.getSchema('todo-show').properties
    callback(cacheConfigSchema)
  })
}
