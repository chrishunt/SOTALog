package com.sotalog.android.domain.models

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.Date

@Entity(tableName = "referenceMetadata")
data class ReferenceMetadata(
    @PrimaryKey
    val key: String,
    val lastRefreshed: Date? = null,
    val recordCount: Int? = null,
)
