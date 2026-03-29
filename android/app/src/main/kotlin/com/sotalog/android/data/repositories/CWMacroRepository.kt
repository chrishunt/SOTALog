package com.sotalog.android.data.repositories

import com.sotalog.android.data.local.database.dao.CWMacroDao
import com.sotalog.android.domain.models.CWMacro
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class CWMacroRepository @Inject constructor(
    private val cwMacroDao: CWMacroDao,
) {

    suspend fun fetchAll(): List<CWMacro> = withContext(Dispatchers.IO) {
        cwMacroDao.getAll()
    }

    suspend fun save(macro: CWMacro): CWMacro = withContext(Dispatchers.IO) {
        if (macro.id != null && macro.id > 0) {
            cwMacroDao.update(macro)
            macro
        } else {
            cwMacroDao.insertAll(listOf(macro))
            macro
        }
    }

    suspend fun resetToDefaults() = withContext(Dispatchers.IO) {
        cwMacroDao.deleteAll()
        cwMacroDao.insertAll(CWMacro.defaults)
    }

    suspend fun resetOne(position: Int) = withContext(Dispatchers.IO) {
        val default = CWMacro.defaults.firstOrNull { it.position == position } ?: return@withContext
        val existing = cwMacroDao.getAll().firstOrNull { it.position == position }
        if (existing != null) {
            cwMacroDao.update(existing.copy(label = default.label, template = default.template))
        } else {
            cwMacroDao.insertAll(listOf(default))
        }
    }
}
