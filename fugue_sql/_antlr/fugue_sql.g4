/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * This file is based on
 * https://github.com/apache/spark/blob/d2bec5e265e0aa4fa527c3f43cfe738cdbdc4598/sql/catalyst/src/main/antlr4/org/apache/spark/sql/catalyst/parser/SqlBase.g4
 */

grammar fugue_sql;

@members {
# When false, INTERSECT is given the greater precedence over the other set
# operations (UNION, EXCEPT and MINUS) as per the SQL standard.
legacy_setops_precedence_enbled = False

# When false, a literal with an exponent would be converted into
# double type rather than decimal type.
legacy_exponent_literal_as_decimal_enabled = False

# Verify whether current token is a valid decimal token (which contains dot).
# Returns true if the character that follows the token is not a digit or letter or underscore.

#  For example:
# For char stream "2.3", "2." is not a valid decimal token, because it is followed by digit '3'.
# For char stream "2.3_", "2.3" is not a valid decimal token, because it is followed by '_'.
# For char stream "2.3W", "2.3" is not a valid decimal token, because it is followed by 'W'.
# For char stream "12.0D 34.E2+0.12 "  12.0D is a valid decimal token because it is followed
# by a space. 34.E2 is a valid decimal token because it is followed by symbol '+'
# which is not a digit or letter or underscore.
def isValidDecimal(self):
    return True  # TODO: remove this
    nextChar = self._input.LA(1);
    if (nextChar >= 'A' and nextChar <= 'Z') or (nextChar >= '0' and nextChar <= '9') or nextChar == '_':
        return False
    else:
        return True

# When true, the behavior of keywords follows ANSI SQL standard.
@property
def SQL_standard_keyword_behavior(self):
    if "_ansi_sql" in self.__dict__:
        return self._ansi_sql
    return False

# This method will be called when we see '/ *' and try to match it as a bracketed comment.
# If the next character is '+', it should be parsed as hint later, and we cannot match
# it as a bracketed comment.

# Returns true if the next character is '+'.
def isHint(self):
    return False  # TODO: remove this
    nextChar = self._input.LA(1);
    if nextChar == '+':
        return True
    else:
        return False


@property
def allUpperCase(self):
    if "_all_upper_case" in self.__dict__:
        return self._all_upper_case
    return False

@property
def simpleAssign(self):
    if "_simple_assign" in self.__dict__:
        return self._simple_assign
    return False

}



//==========================
// Start of the Fugue rules
//==========================

fugueLanguage:
    fugueSingleTask+ EOF
    ;

fugueSingleStatement:
    fugueSingleTask EOF
    ;

fugueSingleTask
    : fugueNestableTask
    | fugueOutputTransformTask
    | fugueOutputTask
    | fuguePrintTask
    | fugueSaveTask
    | fugueModuleTask
    ;

fugueNestableTask
    : (assign=fugueAssignment)? q=query (checkpoint=fugueCheckpoint)? (broadcast=fugueBroadcast)? (y=fugueYield)?
    ;

fugueNestableTaskCollectionNoSelect
    : fugueTransformTask
    | fugueProcessTask
    | fugueZipTask
    | fugueCreateTask
    | fugueCreateDataTask
    | fugueLoadTask
    | fugueSaveAndUseTask
    | fugueRenameColumnsTask
    | fugueAlterColumnsTask
    | fugueDropColumnsTask
    | fugueDropnaTask
    | fugueFillnaTask
    | fugueSampleTask
    | fugueTakeTask
    ;

fugueTransformTask:
    TRANSFORM (dfs=fugueDataFrames)? (partition=fuguePrepartition)? params=fugueSingleOutputExtensionCommonWild (CALLBACK callback=fugueExtension)?
    ;

fugueProcessTask:
    PROCESS (dfs=fugueDataFrames)? (partition=fuguePrepartition)? params=fugueSingleOutputExtensionCommon
    ;

fugueSaveAndUseTask:
    SAVE AND USE (df=fugueDataFrame)? (partition=fuguePrepartition)? m=fugueSaveMode (single=fugueSingleFile)? (fmt=fugueFileFormat)? path=fuguePath (params=fugueParams)?
    ;

fugueRenameColumnsTask:
    RENAME COLUMNS cols=fugueRenameExpression (FROM df=fugueDataFrame)?
    ;

fugueAlterColumnsTask:
    ALTER COLUMNS cols=fugueSchema (FROM df=fugueDataFrame)?
    ;

fugueDropColumnsTask:
    DROP COLUMNS cols=fugueCols (IF EXISTS)? (FROM df=fugueDataFrame)?
    ;

fugueDropnaTask:
    DROP ROWS IF how=(ALL|ANY) (NULL|NULLS) (ON cols=fugueCols)? (FROM df=fugueDataFrame)?
    ;

fugueFillnaTask:
    FILL (NULL|NULLS) params=fugueParams (FROM df=fugueDataFrame)?
    ;

fugueSampleTask:
    SAMPLE REPLACE? method=fugueSampleMethod (SEED seed=INTEGER_VALUE)? (FROM df=fugueDataFrame)?
    ;

fugueTakeTask:
    TAKE (rows=INTEGER_VALUE (ROW|ROWS))? (FROM df=fugueDataFrame)? ((partition=fuguePrepartition)|(PRESORT presort=fugueColsSort))? ((NULL|NULLS) na_position=(FIRST|LAST))?
    ;

fugueZipTask:
    ZIP dfs=fugueDataFrames (how=fugueZipType)? (BY by=fugueCols)? (PRESORT presort=fugueColsSort)?
    ;

fugueCreateTask:
    CREATE params=fugueSingleOutputExtensionCommon
    ;

fugueCreateDataTask:
    CREATE DATA? data=fugueJsonArray SCHEMA schema=fugueSchema
    ;

fugueLoadTask:
    LOAD (fmt=fugueFileFormat)? path=fuguePath (params=fugueParams)? (COLUMNS columns=fugueLoadColumns)?
    ;

fugueOutputTask:
    OUTPUT (dfs=fugueDataFrames)? (partition=fuguePrepartition)? USING using=fugueExtension (params=fugueParams)?
    ;

fuguePrintTask
    : PRINT rows=INTEGER_VALUE (ROW|ROWS) (FROM dfs=fugueDataFrames)? (count=ROWCOUNT)? (TITLE title=STRING)?
    | PRINT (dfs=fugueDataFrames)? (count=ROWCOUNT)? (TITLE title=STRING)?
    ;

fugueSaveTask:
    SAVE (df=fugueDataFrame)? (partition=fuguePrepartition)? m=fugueSaveMode (single=fugueSingleFile)? (fmt=fugueFileFormat)? path=fuguePath (params=fugueParams)?
    ;

fugueOutputTransformTask:
    OUTTRANSFORM (dfs=fugueDataFrames)? (partition=fuguePrepartition)? USING using=fugueExtension (params=fugueParams)? (CALLBACK callback=fugueExtension)?
    ;

fugueModuleTask:
    (assign=fugueAssignment)? SUB (dfs=fugueDataFrames)? USING using=fugueExtension (params=fugueParams)?
    ;

fugueSqlEngine:
    CONNECT using=fugueExtension (params=fugueParams)?
    ;

fugueSingleFile
    : single=SINGLE
    ;

fugueLoadColumns
    : schema=fugueSchema
    | cols = fugueCols
    ;

fugueSaveMode
    : TO
    | OVERWRITE
    | APPEND
    ;

fugueFileFormat
    : PARQUET
    | CSV
    | JSON
    ;

fuguePath
    : STRING
    ;

fugueCheckpoint
    : LAZY? (PERSIST | WEAK CHECKPOINT) (params=fugueParams)?                                                                                       #fugueCheckpointWeak
    | LAZY? STRONG? CHECKPOINT (partition=fuguePrepartition)? (single=fugueSingleFile)? (params=fugueParams)?                                       #fugueCheckpointStrong
    | LAZY? DETERMINISTIC CHECKPOINT (ns=fugueCheckpointNamespace)? (partition=fuguePrepartition)? (single=fugueSingleFile)? (params=fugueParams)?  #fugueCheckpointDeterministic
    ;

fugueCheckpointNamespace
    : STRING
    ;

fugueYield
    : YIELD (DATAFRAME|FILE) (AS name=fugueIdentifier)?
    ;

fugueBroadcast:
    BROADCAST
    ;

fugueDataFrames
    : fugueDataFrame (',' fugueDataFrame)*          #fugueDataFramesList
    | fugueDataFramePair (',' fugueDataFramePair)*  #fugueDataFramesDict
    ;

fugueDataFramePair
    : key=fugueIdentifier (':' | EQUAL) value=fugueDataFrame
    ;

fugueDataFrame
    : fugueIdentifier fugueDataFrameMember?         #fugueDataFrameSource
    | '(' task=fugueNestableTask ')'                #fugueDataFrameNested
    ;

fugueDataFrameMember
    : '[' (index=INTEGER_VALUE|key=fugueIdentifier) ']'
    ;

fugueAssignment:
    varname=fugueIdentifier sign=fugueAssignmentSign
    ;

fugueAssignmentSign
    : COLONEQUAL
    | {self.simpleAssign}? EQUAL
    ;

fugueSingleOutputExtensionCommonWild:
    USING using=fugueExtension (params=fugueParams)? (SCHEMA schema=fugueWildSchema)?
    ;

fugueSingleOutputExtensionCommon:
    USING using=fugueExtension (params=fugueParams)? (SCHEMA schema=fugueSchema)?
    ;

fugueExtension:
    fugueIdentifier ('.' fugueIdentifier)*
    ;

fugueSampleMethod:
    percentage=(INTEGER_VALUE | DECIMAL_VALUE) PERCENTLIT
    | rows=INTEGER_VALUE ROWS
    ;

fugueZipType
    : CROSS
    | INNER
    | LEFT OUTER
    | RIGHT OUTER
    | FULL OUTER
    ;

fuguePrepartition
    : (algo=fuguePartitionAlgo)? PREPARTITION num=fuguePartitionNum (BY by=fugueCols)? (PRESORT presort=fugueColsSort)?
    | (algo=fuguePartitionAlgo)? PREPARTITION BY by=fugueCols (PRESORT presort=fugueColsSort)?
    ;

fuguePartitionAlgo
    : HASH | RAND | EVEN
    ;

fuguePartitionNum
    : fuguePartitionNumber
    | '(' fuguePartitionNum ')'
    | fuguePartitionNum (PLUS|MINUS|ASTERISK|SLASH) fuguePartitionNum
    ;

fuguePartitionNumber
    : MINUS? DECIMAL_VALUE
    | MINUS? INTEGER_VALUE
    | ROWCOUNT
    | CONCURRENCY
    ;

fugueParams
    : PARAMS pairs=fugueJsonPairs   #fugueParamsPairs
    | PARAMS? obj=fugueJsonObj      #fugueParamsObj
    ;

fugueCols:
    fugueColumnIdentifier (',' fugueColumnIdentifier)*
    ;

fugueColsSort:
    fugueColSort (',' fugueColSort)*
    ;

fugueColSort:
    fugueColumnIdentifier (ASC | DESC)?
    ;

fugueColumnIdentifier:
    fugueIdentifier
    ;

fugueRenameExpression:
    fugueRenamePair (',' fugueRenamePair)*
    ;

fugueWildSchema:
    fugueWildSchemaPair (',' fugueWildSchemaPair)* fugueSchemaOp*
    ;

fugueWildSchemaPair
    : pair=fugueSchemaPair
    | ASTERISK
    ;

fugueSchemaOp
    : (MINUS|TILDE) fugueSchemaKey (',' fugueSchemaKey)*
    | PLUS fugueSchema
    ;

fugueSchema:
    fugueSchemaPair (',' fugueSchemaPair)*
    ;

fugueSchemaPair:
    key=fugueSchemaKey ':' value=fugueSchemaType
    ;

fugueSchemaKey:
    fugueIdentifier
    ;

fugueSchemaType
    : fugueIdentifier               #fugueSchemaSimpleType
    | '[' fugueSchemaType ']'       #fugueSchemaListType
    | '{' fugueSchema '}'           #fugueSchemaStructType
    ;

fugueRenamePair:
    key=fugueSchemaKey ':' value=fugueSchemaKey
    ;

// From https://github.com/antlr/grammars-v4/blob/master/json/JSON.g4

fugueJson
    : fugueJsonValue
    ;

fugueJsonObj
    : '{' fugueJsonPairs ','? '}'
    | '{' '}'
    | '(' fugueJsonPairs ','? ')'
    | '(' ')'
    ;

fugueJsonPairs
    : fugueJsonPair (',' fugueJsonPair)*
    ;

fugueJsonPair
    : key=fugueJsonKey (EQUAL | ':') value=fugueJsonValue
    ;

fugueJsonKey
    : fugueIdentifier
    | fugueJsonString
    ;

fugueJsonArray
    : '[' fugueJsonValue (',' fugueJsonValue)* ','? ']'
    | '[' ']'
    ;

fugueJsonValue
    : fugueJsonString
    | fugueJsonNumber
    | fugueJsonObj
    | fugueJsonArray
    | fugueJsonBool
    | fugueJsonNull
    ;

fugueJsonNumber
    : number
    ;

fugueJsonString
    : STRING
    ;

fugueJsonBool
    : 'true'
    | TRUE
    | 'false'
    | FALSE
    ;

fugueJsonNull
    : 'null'
    | NULL
    ;

fugueIdentifier:
    identifier
    ;


//========================
// End of the Fugue rules
//========================


singleStatement
    : statement ';'* EOF
    ;

singleExpression
    : namedExpression EOF
    ;

singleTableIdentifier
    : tableIdentifier EOF
    ;

singleMultipartIdentifier
    : multipartIdentifier EOF
    ;

singleFunctionIdentifier
    : functionIdentifier EOF
    ;

singleDataType
    : dataType EOF
    ;

singleTableSchema
    : colTypeList EOF
    ;

statement
    : query                                                            #statementDefault
    | ctes? dmlStatementNoWith                                         #dmlStatement
    | USE NAMESPACE? multipartIdentifier                               #use
    | CREATE namespace (IF NOT EXISTS)? multipartIdentifier
        (commentSpec |
         locationSpec |
         (WITH (DBPROPERTIES | PROPERTIES) tablePropertyList))*        #createNamespace
    | ALTER namespace multipartIdentifier
        SET (DBPROPERTIES | PROPERTIES) tablePropertyList              #setNamespaceProperties
    | ALTER namespace multipartIdentifier
        SET locationSpec                                               #setNamespaceLocation
    | DROP namespace (IF EXISTS)? multipartIdentifier
        (RESTRICT | CASCADE)?                                          #dropNamespace
    | SHOW (DATABASES | NAMESPACES) ((FROM | IN) multipartIdentifier)?
        (LIKE? pattern=STRING)?                                        #showNamespaces
    | createTableHeader ('(' colTypeList ')')? tableProvider
        createTableClauses
        (AS? query)?                                                   #createTable
    | createTableHeader ('(' columns=colTypeList ')')?
        (commentSpec |
        (PARTITIONED BY '(' partitionColumns=colTypeList ')' |
        PARTITIONED BY partitionColumnNames=identifierList) |
        bucketSpec |
        skewSpec |
        rowFormat |
        createFileFormat |
        locationSpec |
        (TBLPROPERTIES tableProps=tablePropertyList))*
        (AS? query)?                                                   #createHiveTable
    | CREATE TABLE (IF NOT EXISTS)? target=tableIdentifier
        LIKE source=tableIdentifier
        (tableProvider |
        rowFormat |
        createFileFormat |
        locationSpec |
        (TBLPROPERTIES tableProps=tablePropertyList))*                 #createTableLike
    | replaceTableHeader ('(' colTypeList ')')? tableProvider
        createTableClauses
        (AS? query)?                                                   #replaceTable
    | ANALYZE TABLE multipartIdentifier partitionSpec? COMPUTE STATISTICS
        (identifier | FOR COLUMNS identifierSeq | FOR ALL COLUMNS)?    #analyze
    | ALTER TABLE multipartIdentifier
        ADD (COLUMN | COLUMNS)
        columns=qualifiedColTypeWithPositionList                       #addTableColumns
    | ALTER TABLE multipartIdentifier
        ADD (COLUMN | COLUMNS)
        '(' columns=qualifiedColTypeWithPositionList ')'               #addTableColumns
    | ALTER TABLE table=multipartIdentifier
        RENAME COLUMN
        ifrom=multipartIdentifier TO to=errorCapturingIdentifier        #renameTableColumn
    | ALTER TABLE multipartIdentifier
        DROP (COLUMN | COLUMNS)
        '(' columns=multipartIdentifierList ')'                        #dropTableColumns
    | ALTER TABLE multipartIdentifier
        DROP (COLUMN | COLUMNS) columns=multipartIdentifierList        #dropTableColumns
    | ALTER (TABLE | VIEW) ifrom=multipartIdentifier
        RENAME TO to=multipartIdentifier                               #renameTable
    | ALTER (TABLE | VIEW) multipartIdentifier
        SET TBLPROPERTIES tablePropertyList                            #setTableProperties
    | ALTER (TABLE | VIEW) multipartIdentifier
        UNSET TBLPROPERTIES (IF EXISTS)? tablePropertyList             #unsetTableProperties
    | ALTER TABLE table=multipartIdentifier
        (ALTER | CHANGE) COLUMN? column=multipartIdentifier
        alterColumnAction?                                             #alterTableAlterColumn
    | ALTER TABLE table=multipartIdentifier partitionSpec?
        CHANGE COLUMN?
        colName=multipartIdentifier colType colPosition?               #hiveChangeColumn
    | ALTER TABLE table=multipartIdentifier partitionSpec?
        REPLACE COLUMNS
        '(' columns=qualifiedColTypeWithPositionList ')'               #hiveReplaceColumns
    | ALTER TABLE multipartIdentifier (partitionSpec)?
        SET SERDE STRING (WITH SERDEPROPERTIES tablePropertyList)?     #setTableSerDe
    | ALTER TABLE multipartIdentifier (partitionSpec)?
        SET SERDEPROPERTIES tablePropertyList                          #setTableSerDe
    | ALTER (TABLE | VIEW) multipartIdentifier ADD (IF NOT EXISTS)?
        partitionSpecLocation+                                         #addTablePartition
    | ALTER TABLE multipartIdentifier
        ifrom=partitionSpec RENAME TO to=partitionSpec                  #renameTablePartition
    | ALTER (TABLE | VIEW) multipartIdentifier
        DROP (IF EXISTS)? partitionSpec (',' partitionSpec)* PURGE?    #dropTablePartitions
    | ALTER TABLE multipartIdentifier
        (partitionSpec)? SET locationSpec                              #setTableLocation
    | ALTER TABLE multipartIdentifier RECOVER PARTITIONS               #recoverPartitions
    | DROP TABLE (IF EXISTS)? multipartIdentifier PURGE?               #dropTable
    | DROP VIEW (IF EXISTS)? multipartIdentifier                       #dropView
    | CREATE (OR REPLACE)? (GLOBAL? TEMPORARY)?
        VIEW (IF NOT EXISTS)? multipartIdentifier
        identifierCommentList?
        (commentSpec |
         (PARTITIONED ON identifierList) |
         (TBLPROPERTIES tablePropertyList))*
        AS query                                                       #createView
    | CREATE (OR REPLACE)? GLOBAL? TEMPORARY VIEW
        tableIdentifier ('(' colTypeList ')')? tableProvider
        (OPTIONS tablePropertyList)?                                   #createTempViewUsing
    | ALTER VIEW multipartIdentifier AS? query                         #alterViewQuery
    | CREATE (OR REPLACE)? TEMPORARY? FUNCTION (IF NOT EXISTS)?
        multipartIdentifier AS className=STRING
        (USING resource (',' resource)*)?                              #createFunction
    | DROP TEMPORARY? FUNCTION (IF EXISTS)? multipartIdentifier        #dropFunction
    | EXPLAIN (LOGICAL | FORMATTED | EXTENDED | CODEGEN | COST)?
        statement                                                      #explain
    | SHOW TABLES ((FROM | IN) multipartIdentifier)?
        (LIKE? pattern=STRING)?                                        #showTables
    | SHOW TABLE EXTENDED ((FROM | IN) ns=multipartIdentifier)?
        LIKE pattern=STRING partitionSpec?                             #showTable
    | SHOW TBLPROPERTIES table=multipartIdentifier
        ('(' key=tablePropertyKey ')')?                                #showTblProperties
    | SHOW COLUMNS (FROM | IN) table=multipartIdentifier
        ((FROM | IN) ns=multipartIdentifier)?                          #showColumns
    | SHOW VIEWS ((FROM | IN) multipartIdentifier)?
        (LIKE? pattern=STRING)?                                        #showViews
    | SHOW PARTITIONS multipartIdentifier partitionSpec?               #showPartitions
    | SHOW identifier? FUNCTIONS
        (LIKE? (multipartIdentifier | pattern=STRING))?                #showFunctions
    | SHOW CREATE TABLE multipartIdentifier (AS SERDE)?                #showCreateTable
    | SHOW CURRENT NAMESPACE                                           #showCurrentNamespace
    | (DESC | DESCRIBE) FUNCTION EXTENDED? describeFuncName            #describeFunction
    | (DESC | DESCRIBE) namespace EXTENDED?
        multipartIdentifier                                            #describeNamespace
    | (DESC | DESCRIBE) TABLE? option=(EXTENDED | FORMATTED)?
        multipartIdentifier partitionSpec? describeColName?            #describeRelation
    | (DESC | DESCRIBE) QUERY? query                                   #describeQuery
    | COMMENT ON namespace multipartIdentifier IS
        comment=(STRING | NULL)                                        #commentNamespace
    | COMMENT ON TABLE multipartIdentifier IS comment=(STRING | NULL)  #commentTable
    | REFRESH TABLE multipartIdentifier                                #refreshTable
    | REFRESH (STRING | .*?)                                           #refreshResource
    | CACHE LAZY? TABLE multipartIdentifier
        (OPTIONS options=tablePropertyList)? (AS? query)?              #cacheTable
    | UNCACHE TABLE (IF EXISTS)? multipartIdentifier                   #uncacheTable
    | CLEAR CACHE                                                      #clearCache
    | LOAD DATA LOCAL? INPATH path=STRING OVERWRITE? INTO TABLE
        multipartIdentifier partitionSpec?                             #loadData
    | TRUNCATE TABLE multipartIdentifier partitionSpec?                #truncateTable
    | MSCK REPAIR TABLE multipartIdentifier                            #repairTable
    | op=(ADD | LIST) identifier (STRING | .*?)                        #manageResource
    | SET ROLE .*?                                                     #failNativeCommand
    | SET .*?                                                          #setConfiguration
    | RESET                                                            #resetConfiguration
    | unsupportedHiveNativeCommands .*?                                #failNativeCommand
    ;

unsupportedHiveNativeCommands
    : kw1=CREATE kw2=ROLE
    | kw1=DROP kw2=ROLE
    | kw1=GRANT kw2=ROLE?
    | kw1=REVOKE kw2=ROLE?
    | kw1=SHOW kw2=GRANT
    | kw1=SHOW kw2=ROLE kw3=GRANT?
    | kw1=SHOW kw2=PRINCIPALS
    | kw1=SHOW kw2=ROLES
    | kw1=SHOW kw2=CURRENT kw3=ROLES
    | kw1=EXPORT kw2=TABLE
    | kw1=IMPORT kw2=TABLE
    | kw1=SHOW kw2=COMPACTIONS
    | kw1=SHOW kw2=CREATE kw3=TABLE
    | kw1=SHOW kw2=TRANSACTIONS
    | kw1=SHOW kw2=INDEXES
    | kw1=SHOW kw2=LOCKS
    | kw1=CREATE kw2=INDEX
    | kw1=DROP kw2=INDEX
    | kw1=ALTER kw2=INDEX
    | kw1=LOCK kw2=TABLE
    | kw1=LOCK kw2=DATABASE
    | kw1=UNLOCK kw2=TABLE
    | kw1=UNLOCK kw2=DATABASE
    | kw1=CREATE kw2=TEMPORARY kw3=MACRO
    | kw1=DROP kw2=TEMPORARY kw3=MACRO
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=NOT kw4=CLUSTERED
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=CLUSTERED kw4=BY
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=NOT kw4=SORTED
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=SKEWED kw4=BY
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=NOT kw4=SKEWED
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=NOT kw4=STORED kw5=AS kw6=DIRECTORIES
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=SET kw4=SKEWED kw5=LOCATION
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=EXCHANGE kw4=PARTITION
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=ARCHIVE kw4=PARTITION
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=UNARCHIVE kw4=PARTITION
    | kw1=ALTER kw2=TABLE tableIdentifier kw3=TOUCH
    | kw1=ALTER kw2=TABLE tableIdentifier partitionSpec? kw3=COMPACT
    | kw1=ALTER kw2=TABLE tableIdentifier partitionSpec? kw3=CONCATENATE
    | kw1=ALTER kw2=TABLE tableIdentifier partitionSpec? kw3=SET kw4=FILEFORMAT
    | kw1=ALTER kw2=TABLE tableIdentifier partitionSpec? kw3=REPLACE kw4=COLUMNS
    | kw1=START kw2=TRANSACTION
    | kw1=COMMIT
    | kw1=ROLLBACK
    | kw1=DFS
    ;

createTableHeader
    : CREATE TEMPORARY? EXTERNAL? TABLE (IF NOT EXISTS)? multipartIdentifier
    ;

replaceTableHeader
    : (CREATE OR)? REPLACE TABLE multipartIdentifier
    ;

bucketSpec
    : CLUSTERED BY identifierList
      (SORTED BY orderedIdentifierList)?
      INTO INTEGER_VALUE BUCKETS
    ;

skewSpec
    : SKEWED BY identifierList
      ON (constantList | nestedConstantList)
      (STORED AS DIRECTORIES)?
    ;

locationSpec
    : LOCATION STRING
    ;

commentSpec
    : COMMENT STRING
    ;

query
    : fugueSqlEngine? ctes? queryTerm queryOrganization
    ;

insertInto
    : INSERT OVERWRITE TABLE? multipartIdentifier (partitionSpec (IF NOT EXISTS)?)?                         #insertOverwriteTable
    | INSERT INTO TABLE? multipartIdentifier partitionSpec? (IF NOT EXISTS)?                                #insertIntoTable
    | INSERT OVERWRITE LOCAL? DIRECTORY path=STRING rowFormat? createFileFormat?                            #insertOverwriteHiveDir
    | INSERT OVERWRITE LOCAL? DIRECTORY (path=STRING)? tableProvider (OPTIONS options=tablePropertyList)?   #insertOverwriteDir
    ;

partitionSpecLocation
    : partitionSpec locationSpec?
    ;

partitionSpec
    : PARTITION '(' partitionVal (',' partitionVal)* ')'
    ;

partitionVal
    : identifier (EQUAL constant)?
    ;

namespace
    : NAMESPACE
    | DATABASE
    | SCHEMA
    ;

describeFuncName
    : qualifiedName
    | STRING
    | comparisonOperator
    | arithmeticOperator
    | predicateOperator
    ;

describeColName
    : nameParts+=identifier ('.' nameParts+=identifier)*
    ;

ctes
    : WITH namedQuery (',' namedQuery)*
    ;

namedQuery
    : name=errorCapturingIdentifier (columnAliases=identifierList)? AS? '(' query ')'
    ;

tableProvider
    : USING multipartIdentifier
    ;

createTableClauses
    :((OPTIONS options=tablePropertyList) |
     (PARTITIONED BY partitioning=transformList) |
     bucketSpec |
     locationSpec |
     commentSpec |
     (TBLPROPERTIES tableProps=tablePropertyList))*
    ;

tablePropertyList
    : '(' tableProperty (',' tableProperty)* ')'
    ;

tableProperty
    : key=tablePropertyKey (EQUAL? value=tablePropertyValue)?
    ;

tablePropertyKey
    : identifier ('.' identifier)*
    | STRING
    ;

tablePropertyValue
    : INTEGER_VALUE
    | DECIMAL_VALUE
    | booleanValue
    | STRING
    ;

constantList
    : '(' constant (',' constant)* ')'
    ;

nestedConstantList
    : '(' constantList (',' constantList)* ')'
    ;

createFileFormat
    : STORED AS fileFormat
    | STORED BY storageHandler
    ;

fileFormat
    : INPUTFORMAT inFmt=STRING OUTPUTFORMAT outFmt=STRING    #tableFileFormat
    | identifier                                             #genericFileFormat
    ;

storageHandler
    : STRING (WITH SERDEPROPERTIES tablePropertyList)?
    ;

resource
    : identifier STRING
    ;

dmlStatementNoWith
    : insertInto queryTerm queryOrganization                                       #singleInsertQuery
    | fromClause multiInsertQueryBody+                                             #multiInsertQuery
    | DELETE FROM multipartIdentifier tableAlias whereClause?                      #deleteFromTable
    | UPDATE multipartIdentifier tableAlias setClause whereClause?                 #updateTable
    | MERGE INTO target=multipartIdentifier targetAlias=tableAlias
        USING (source=multipartIdentifier |
          '(' sourceQuery=query')') sourceAlias=tableAlias
        ON mergeCondition=booleanExpression
        matchedClause*
        notMatchedClause*                                                          #mergeIntoTable
    ;

queryOrganization
    : (ORDER BY order+=sortItem (',' order+=sortItem)*)?
      (CLUSTER BY clusterBy+=expression (',' clusterBy+=expression)*)?
      (DISTRIBUTE BY distributeBy+=expression (',' distributeBy+=expression)*)?
      (SORT BY sort+=sortItem (',' sort+=sortItem)*)?
      windowClause?
      (LIMIT (ALL | limit=expression))?
    ;

multiInsertQueryBody
    : insertInto fromStatementBody
    ;

queryTerm
    : queryPrimary                                                                       #queryTermDefault
    | fugueNestableTaskCollectionNoSelect                                                #fugueTerm
    | left=queryTerm {fugue_sqlParser.legacy_setops_precedence_enbled}?
        operator=(INTERSECT | UNION | EXCEPT | SETMINUS) setQuantifier? right=queryTerm  #setOperation
    | left=queryTerm {not fugue_sqlParser.legacy_setops_precedence_enbled}?
        operator=INTERSECT setQuantifier? right=queryTerm                                #setOperation
    | left=queryTerm {not fugue_sqlParser.legacy_setops_precedence_enbled}?
        operator=(UNION | EXCEPT | SETMINUS) setQuantifier? right=queryTerm              #setOperation
    ;

queryPrimary
    : querySpecification                                                    #queryPrimaryDefault
    | fromStatement                                                         #fromStmt
    | TABLE multipartIdentifier                                             #table
    | inlineTable                                                           #inlineTableDefault1
    // TODO: subquery is causing ambiguity such as SELECT * FROM (SELECT * FROM a)
    // it thinks the first FROM is an identity not a keyword
    // when SQL_standard_keyword_behavior=False
    //| '(' query ')'                                                         #subquery
    ;

sortItem
    : expression ordering=(ASC | DESC)? (NULLS nullOrder=(LAST | FIRST))?
    ;

fromStatement
    : fromClause fromStatementBody+
    ;

fromStatementBody
    : transformClause
      whereClause?
      queryOrganization
    | selectClause
      lateralView*
      whereClause?
      aggregationClause?
      havingClause?
      windowClause?
      queryOrganization
    ;

querySpecification
    : transformClause
      optionalFromClause
      whereClause?                                                          #transformQuerySpecification
    | selectClause
      optionalFromClause
      lateralView*
      whereClause?
      aggregationClause?
      havingClause?
      windowClause?                                                         #regularQuerySpecification
    ;

optionalFromClause  // add this to easily capture no FROM cases
    : fromClause?
    ;

transformClause
    : (SELECT kind=TRANSFORM '(' namedExpressionSeq ')'
            | kind=MAP namedExpressionSeq
            | kind=REDUCE namedExpressionSeq)
      inRowFormat=rowFormat?
      (RECORDWRITER recordWriter=STRING)?
      USING script=STRING
      (AS (identifierSeq | colTypeList | ('(' (identifierSeq | colTypeList) ')')))?
      outRowFormat=rowFormat?
      (RECORDREADER recordReader=STRING)?
    ;

selectClause
    : SELECT (hints+=hint)* setQuantifier? namedExpressionSeq
    ;

setClause
    : SET assignmentList
    ;

matchedClause
    : WHEN MATCHED (AND matchedCond=booleanExpression)? THEN matchedAction
    ;
notMatchedClause
    : WHEN NOT MATCHED (AND notMatchedCond=booleanExpression)? THEN notMatchedAction
    ;

matchedAction
    : DELETE
    | UPDATE SET ASTERISK
    | UPDATE SET assignmentList
    ;

notMatchedAction
    : INSERT ASTERISK
    | INSERT '(' columns=multipartIdentifierList ')'
        VALUES '(' expression (',' expression)* ')'
    ;

assignmentList
    : assignment (',' assignment)*
    ;

assignment
    : key=multipartIdentifier EQUAL value=expression
    ;

whereClause
    : WHERE booleanExpression
    ;

havingClause
    : HAVING booleanExpression
    ;

hint
    : '/*+' hintStatements+=hintStatement (','? hintStatements+=hintStatement)* '*/'
    ;

hintStatement
    : hintName=identifier
    | hintName=identifier '(' parameters+=primaryExpression (',' parameters+=primaryExpression)* ')'
    ;

fromClause
    : FROM relation (',' relation)* lateralView* pivotClause?
    ;

aggregationClause
    : GROUP BY groupingExpressions+=expression (',' groupingExpressions+=expression)* (
      WITH kind=ROLLUP
    | WITH kind=CUBE
    | kind=GROUPING SETS '(' groupingSet (',' groupingSet)* ')')?
    | GROUP BY kind=GROUPING SETS '(' groupingSet (',' groupingSet)* ')'
    ;

groupingSet
    : '(' (expression (',' expression)*)? ')'
    | expression
    ;

pivotClause
    : PIVOT '(' aggregates=namedExpressionSeq FOR pivotColumn IN '(' pivotValues+=pivotValue (',' pivotValues+=pivotValue)* ')' ')'
    ;

pivotColumn
    : identifiers+=identifier
    | '(' identifiers+=identifier (',' identifiers+=identifier)* ')'
    ;

pivotValue
    : expression (AS? identifier)?
    ;

lateralView
    : LATERAL VIEW (OUTER)? qualifiedName '(' (expression (',' expression)*)? ')' tblName=identifier (AS? colName+=identifier (',' colName+=identifier)*)?
    ;

setQuantifier
    : DISTINCT
    | ALL
    ;

relation
    : relationPrimary joinRelation*
    ;

joinRelation
    : (joinType) JOIN right=relationPrimary joinCriteria?
    | NATURAL joinType JOIN right=relationPrimary
    ;

joinType
    : INNER?
    | CROSS
    | LEFT OUTER?
    | LEFT? SEMI
    | RIGHT OUTER?
    | FULL OUTER?
    | LEFT? ANTI
    ;

joinCriteria
    : ON booleanExpression
    | USING identifierList
    ;

sample
    : TABLESAMPLE '(' sampleMethod? ')'
    ;

sampleMethod
    : negativeSign=MINUS? percentage=(INTEGER_VALUE | DECIMAL_VALUE) PERCENTLIT   #sampleByPercentile
    | expression ROWS                                                             #sampleByRows
    | sampleType=BUCKET numerator=INTEGER_VALUE OUT OF denominator=INTEGER_VALUE
        (ON (identifier | qualifiedName '(' ')'))?                                #sampleByBucket
    | bytes=expression                                                            #sampleByBytes
    ;

identifierList
    : '(' identifierSeq ')'
    ;

identifierSeq
    : ident+=errorCapturingIdentifier (',' ident+=errorCapturingIdentifier)*
    ;

orderedIdentifierList
    : '(' orderedIdentifier (',' orderedIdentifier)* ')'
    ;

orderedIdentifier
    : ident=errorCapturingIdentifier ordering=(ASC | DESC)?
    ;

identifierCommentList
    : '(' identifierComment (',' identifierComment)* ')'
    ;

identifierComment
    : identifier commentSpec?
    ;

relationPrimary
    : multipartIdentifier fugueDataFrameMember? sample? tableAlias  #tableName
    | '(' query ')' sample? tableAlias                              #aliasedQuery
    | '(' relation ')' sample? tableAlias                           #aliasedRelation
    | inlineTable                                                   #inlineTableDefault2
    | functionTable                                                 #tableValuedFunction
    ;

inlineTable
    : VALUES expression (',' expression)* tableAlias
    ;

functionTable
    : funcName=errorCapturingIdentifier '(' (expression (',' expression)*)? ')' tableAlias
    ;

tableAlias
    : (AS? strictIdentifier identifierList?)?
    ;

rowFormat
    : ROW FORMAT SERDE name=STRING (WITH SERDEPROPERTIES props=tablePropertyList)?  #rowFormatSerde
    | ROW FORMAT DELIMITED
      (FIELDS TERMINATED BY fieldsTerminatedBy=STRING (ESCAPED BY escapedBy=STRING)?)?
      (COLLECTION ITEMS TERMINATED BY collectionItemsTerminatedBy=STRING)?
      (MAP KEYS TERMINATED BY keysTerminatedBy=STRING)?
      (LINES TERMINATED BY linesSeparatedBy=STRING)?
      (NULL DEFINED AS nullDefinedAs=STRING)?                                       #rowFormatDelimited
    ;

multipartIdentifierList
    : multipartIdentifier (',' multipartIdentifier)*
    ;

multipartIdentifier
    : parts+=errorCapturingIdentifier ('.' parts+=errorCapturingIdentifier)*
    ;

tableIdentifier
    : (db=errorCapturingIdentifier '.')? table=errorCapturingIdentifier
    ;

functionIdentifier
    : (db=errorCapturingIdentifier '.')? function=errorCapturingIdentifier
    ;

namedExpression
    : expression (AS? (name=errorCapturingIdentifier | identifierList))?
    ;

namedExpressionSeq
    : namedExpression (',' namedExpression)*
    ;

transformList
    : '(' transforms+=transform (',' transforms+=transform)* ')'
    ;

transform
    : qualifiedName                                                           #identityTransform
    | transformName=identifier
      '(' argument+=transformArgument (',' argument+=transformArgument)* ')'  #applyTransform
    ;

transformArgument
    : qualifiedName
    | constant
    ;

expression
    : booleanExpression
    ;

booleanExpression
    : NOT booleanExpression                                        #logicalNot
    | EXISTS '(' query ')'                                         #exists
    | valueExpression predicate?                                   #predicated
    | left=booleanExpression operator=AND right=booleanExpression  #logicalBinary
    | left=booleanExpression operator=OR right=booleanExpression   #logicalBinary
    ;

predicate
    : NOT? kind=BETWEEN lower=valueExpression AND upper=valueExpression
    | NOT? kind=IN '(' expression (',' expression)* ')'
    | NOT? kind=IN '(' query ')'
    | NOT? kind=RLIKE pattern=valueExpression
    | NOT? kind=LIKE quantifier=(ANY | SOME | ALL) ('('')' | '(' expression (',' expression)* ')')
    | NOT? kind=LIKE pattern=valueExpression (ESCAPE escapeChar=STRING)?
    | IS NOT? kind=NULL
    | IS NOT? kind=(TRUE | FALSE | UNKNOWN)
    | IS NOT? kind=DISTINCT FROM right=valueExpression
    ;

valueExpression
    : primaryExpression                                                                      #valueExpressionDefault
    | operator=(MINUS | PLUS | TILDE) valueExpression                                        #arithmeticUnary
    | left=valueExpression operator=(ASTERISK | SLASH | PERCENT | DIV) right=valueExpression #arithmeticBinary
    | left=valueExpression operator=(PLUS | MINUS | CONCAT_PIPE) right=valueExpression       #arithmeticBinary
    | left=valueExpression operator=AMPERSAND right=valueExpression                          #arithmeticBinary
    | left=valueExpression operator=HAT right=valueExpression                                #arithmeticBinary
    | left=valueExpression operator=PIPE right=valueExpression                               #arithmeticBinary
    | left=valueExpression comparisonOperator right=valueExpression                          #comparison
    ;

primaryExpression
    : name=(CURRENT_DATE | CURRENT_TIMESTAMP)                                                  #currentDatetime
    | CASE whenClause+ (ELSE elseExpression=expression)? END                                   #searchedCase
    | CASE value=expression whenClause+ (ELSE elseExpression=expression)? END                  #simpleCase
    | CAST '(' expression AS dataType ')'                                                      #cast
    | STRUCT '(' (argument+=namedExpression (',' argument+=namedExpression)*)? ')'             #struct
    | FIRST '(' expression (IGNORE NULLS)? ')'                                                 #first
    | LAST '(' expression (IGNORE NULLS)? ')'                                                  #last
    | POSITION '(' substr=valueExpression IN istr=valueExpression ')'                           #position
    | constant                                                                                 #constantDefault
    | ASTERISK                                                                                 #star
    | qualifiedName '.' ASTERISK                                                               #star
    | '(' namedExpression (',' namedExpression)+ ')'                                           #rowConstructor
    | '(' query ')'                                                                            #subqueryExpression
    | functionName '(' (setQuantifier? argument+=expression (',' argument+=expression)*)? ')'
       (FILTER '(' WHERE where=booleanExpression ')')? (OVER windowSpec)?                      #functionCall
    | identifier '->' expression                                                               #lambda
    | '(' identifier (',' identifier)+ ')' '->' expression                                     #lambda
    | value=primaryExpression '[' index=valueExpression ']'                                    #subscript
    | identifier                                                                               #columnReference
    | base=primaryExpression '.' fieldName=identifier                                          #dereference
    | '(' expression ')'                                                                       #parenthesizedExpression
    | EXTRACT '(' field=identifier FROM source=valueExpression ')'                             #extract
    | (SUBSTR | SUBSTRING) '(' istr=valueExpression (FROM | ',') pos=valueExpression
      ((FOR | ',') ilen=valueExpression)? ')'                                                   #substring
    | TRIM '(' trimOption=(BOTH | LEADING | TRAILING)? (trimStr=valueExpression)?
       FROM srcStr=valueExpression ')'                                                         #trim
    | OVERLAY '(' iinput=valueExpression PLACING replace=valueExpression
      FROM position=valueExpression (FOR length=valueExpression)? ')'                          #overlay
    ;

constant
    : NULL                                                                                     #nullLiteral
    | interval                                                                                 #intervalLiteral
    | identifier STRING                                                                        #typeConstructor
    | number                                                                                   #numericLiteral
    | booleanValue                                                                             #booleanLiteral
    | STRING+                                                                                  #stringLiteral
    ;

comparisonOperator
    : comparisonEqualOperator | NEQ | NEQJ | LT | LTE | GT | GTE | NSEQ
    ;

comparisonEqualOperator
    : DOUBLEEQUAL
    | EQUAL
    ;

arithmeticOperator
    : PLUS | MINUS | ASTERISK | SLASH | PERCENT | DIV | TILDE | AMPERSAND | PIPE | CONCAT_PIPE | HAT
    ;

predicateOperator
    : OR | AND | IN | NOT
    ;

booleanValue
    : TRUE | FALSE
    ;

interval
    : INTERVAL (errorCapturingMultiUnitsInterval | errorCapturingUnitToUnitInterval)?
    ;

errorCapturingMultiUnitsInterval
    : multiUnitsInterval unitToUnitInterval?
    ;

multiUnitsInterval
    : (intervalValue intervalUnit)+
    ;

errorCapturingUnitToUnitInterval
    : body=unitToUnitInterval (error1=multiUnitsInterval | error2=unitToUnitInterval)?
    ;

unitToUnitInterval
    : value=intervalValue ifrom=intervalUnit TO to=intervalUnit
    ;

intervalValue
    : (PLUS | MINUS)? (INTEGER_VALUE | DECIMAL_VALUE)
    | STRING
    ;

intervalUnit
    : DAY
    | HOUR
    | MINUTE
    | MONTH
    | SECOND
    | YEAR
    | identifier
    ;

colPosition
    : position=FIRST | position=AFTER afterCol=errorCapturingIdentifier
    ;

dataType
    : icomplex=ARRAY '<' dataType '>'                            #complexDataType
    | icomplex=MAP '<' dataType ',' dataType '>'                 #complexDataType
    | icomplex=STRUCT ('<' complexColTypeList? '>' | NEQ)        #complexDataType
    | identifier ('(' INTEGER_VALUE (',' INTEGER_VALUE)* ')')?  #primitiveDataType
    ;

qualifiedColTypeWithPositionList
    : qualifiedColTypeWithPosition (',' qualifiedColTypeWithPosition)*
    ;

qualifiedColTypeWithPosition
    : name=multipartIdentifier dataType (NOT NULL)? commentSpec? colPosition?
    ;

colTypeList
    : colType (',' colType)*
    ;

colType
    : colName=errorCapturingIdentifier dataType (NOT NULL)? commentSpec?
    ;

complexColTypeList
    : complexColType (',' complexColType)*
    ;

complexColType
    : identifier ':' dataType (NOT NULL)? commentSpec?
    ;

whenClause
    : WHEN condition=expression THEN result=expression
    ;

windowClause
    : WINDOW namedWindow (',' namedWindow)*
    ;

namedWindow
    : name=errorCapturingIdentifier AS windowSpec
    ;

windowSpec
    : name=errorCapturingIdentifier         #windowRef
    | '('name=errorCapturingIdentifier')'   #windowRef
    | '('
      ( CLUSTER BY partition+=expression (',' partition+=expression)*
      | ((PARTITION | DISTRIBUTE) BY partition+=expression (',' partition+=expression)*)?
        ((ORDER | SORT) BY sortItem (',' sortItem)*)?)
      windowFrame?
      ')'                                   #windowDef
    ;

windowFrame
    : frameType=RANGE start=frameBound
    | frameType=ROWS start=frameBound
    | frameType=RANGE BETWEEN start=frameBound AND end=frameBound
    | frameType=ROWS BETWEEN start=frameBound AND end=frameBound
    ;

frameBound
    : UNBOUNDED boundType=(PRECEDING | FOLLOWING)
    | boundType=CURRENT ROW
    | expression boundType=(PRECEDING | FOLLOWING)
    ;

qualifiedNameList
    : qualifiedName (',' qualifiedName)*
    ;

functionName
    : qualifiedName
    | FILTER
    | LEFT
    | RIGHT
    ;

qualifiedName
    : identifier ('.' identifier)*
    ;

// this rule is used for explicitly capturing wrong identifiers such as test-table, which should actually be `test-table`
// replace identifier with errorCapturingIdentifier where the immediate follow symbol is not an expression, otherwise
// valid expressions such as "a-b" can be recognized as an identifier
errorCapturingIdentifier
    : identifier errorCapturingIdentifierExtra
    ;

// extra left-factoring grammar
errorCapturingIdentifierExtra
    : (MINUS identifier)+    #errorIdent
    |                        #realIdent
    ;

identifier
    : strictIdentifier
    | {not self.SQL_standard_keyword_behavior}? strictNonReserved
    ;

strictIdentifier
    : IDENTIFIER              #unquotedIdentifier
    | quotedIdentifier        #quotedIdentifierAlternative
    | {self.SQL_standard_keyword_behavior}? ansiNonReserved #unquotedIdentifier
    | {not self.SQL_standard_keyword_behavior}? nonReserved    #unquotedIdentifier
    ;

quotedIdentifier
    : BACKQUOTED_IDENTIFIER
    ;

number
    : {not fugue_sqlParser.legacy_exponent_literal_as_decimal_enabled}? MINUS? EXPONENT_VALUE #exponentLiteral
    | {not fugue_sqlParser.legacy_exponent_literal_as_decimal_enabled}? MINUS? DECIMAL_VALUE  #decimalLiteral
    | {fugue_sqlParser.legacy_exponent_literal_as_decimal_enabled}? MINUS? (EXPONENT_VALUE | DECIMAL_VALUE) #legacyDecimalLiteral
    | MINUS? INTEGER_VALUE            #integerLiteral
    | MINUS? BIGINT_LITERAL           #bigIntLiteral
    | MINUS? SMALLINT_LITERAL         #smallIntLiteral
    | MINUS? TINYINT_LITERAL          #tinyIntLiteral
    | MINUS? DOUBLE_LITERAL           #doubleLiteral
    | MINUS? BIGDECIMAL_LITERAL       #bigDecimalLiteral
    ;

alterColumnAction
    : TYPE dataType
    | commentSpec
    | colPosition
    | setOrDrop=(SET | DROP) NOT NULL
    ;

// When `SQL_standard_keyword_behavior=true`, there are 2 kinds of keywords in Spark SQL.
// - Reserved keywords:
//     Keywords that are reserved and can't be used as identifiers for table, view, column,
//     function, alias, etc.
// - Non-reserved keywords:
//     Keywords that have a special meaning only in particular contexts and can be used as
//     identifiers in other contexts. For example, `EXPLAIN SELECT ...` is a command, but EXPLAIN
//     can be used as identifiers in other places.
// You can find the full keywords list by searching "Start of the keywords list" in this file.
// The non-reserved keywords are listed below. Keywords not in this list are reserved keywords.
ansiNonReserved
    : ADD
    | AFTER
    | ALTER
    | ANALYZE
    | ARCHIVE
    | ARRAY
    | ASC
    | AT
    | BETWEEN
    | BUCKET
    | BUCKETS
    | BY
    | CACHE
    | CASCADE
    | CHANGE
    | CLEAR
    | CLUSTER
    | CLUSTERED
    | CODEGEN
    | COLLECTION
    | COLUMNS
    | COMMENT
    | COMMIT
    | COMPACT
    | COMPACTIONS
    | COMPUTE
    | CONCATENATE
    | COST
    | CUBE
    | CURRENT
    | DATA
    | DATABASE
    | DATABASES
    | DBPROPERTIES
    | DEFINED
    | DELETE
    | DELIMITED
    | DESC
    | DESCRIBE
    | DFS
    | DIRECTORIES
    | DIRECTORY
    | DISTRIBUTE
    | DIV
    | DROP
    | ESCAPED
    | EXCHANGE
    | EXISTS
    | EXPLAIN
    | EXPORT
    | EXTENDED
    | EXTERNAL
    | EXTRACT
    | FIELDS
    | FILEFORMAT
    | FIRST
    | FOLLOWING
    | FORMAT
    | FORMATTED
    | FUNCTION
    | FUNCTIONS
    | GLOBAL
    | GROUPING
    | IF
    | IGNORE
    | IMPORT
    | INDEX
    | INDEXES
    | INPATH
    | INPUTFORMAT
    | INSERT
    | INTERVAL
    | ITEMS
    | KEYS
    | LAST
    | LATERAL
    | LAZY
    | LIKE
    | LIMIT
    | LINES
    | LIST
    | LOAD
    | LOCAL
    | LOCATION
    | LOCK
    | LOCKS
    | LOGICAL
    | MACRO
    | MAP
    | MATCHED
    | MERGE
    | MSCK
    | NAMESPACE
    | NAMESPACES
    | NO
    | NULLS
    | OF
    | OPTION
    | OPTIONS
    | OUT
    | OUTPUTFORMAT
    | OVER
    | OVERLAY
    | OVERWRITE
    | PARTITION
    | PARTITIONED
    | PARTITIONS
    | PERCENTLIT
    | PIVOT
    | PLACING
    | POSITION
    | PRECEDING
    | PRINCIPALS
    | PROPERTIES
    | PURGE
    | QUERY
    | RANGE
    | RECORDREADER
    | RECORDWRITER
    | RECOVER
    | REDUCE
    | REFRESH
    | RENAME
    | REPAIR
    | REPLACE
    | RESET
    | RESTRICT
    | REVOKE
    | RLIKE
    | ROLE
    | ROLES
    | ROLLBACK
    | ROLLUP
    | ROW
    | ROWS
    | SCHEMA
    | SEPARATED
    | SERDE
    | SERDEPROPERTIES
    | SET
    | SETS
    | SHOW
    | SKEWED
    | SORT
    | SORTED
    | START
    | STATISTICS
    | STORED
    | STRATIFY
    | STRUCT
    | SUBSTR
    | SUBSTRING
    | TABLES
    | TABLESAMPLE
    | TBLPROPERTIES
    | TEMPORARY
    | TERMINATED
    | TOUCH
    | TRANSACTION
    | TRANSACTIONS
    | TRANSFORM
    | TRIM
    | TRUE
    | TRUNCATE
    | UNARCHIVE
    | UNBOUNDED
    | UNCACHE
    | UNLOCK
    | UNSET
    | UPDATE
    | USE
    | VALUES
    | VIEW
    | VIEWS
    | WINDOW
    ;

// When `SQL_standard_keyword_behavior=false`, there are 2 kinds of keywords in Spark SQL.
// - Non-reserved keywords:
//     Same definition as the one when `SQL_standard_keyword_behavior=true`.
// - Strict-non-reserved keywords:
//     A strict version of non-reserved keywords, which can not be used as table alias.
// You can find the full keywords list by searching "Start of the keywords list" in this file.
// The strict-non-reserved keywords are listed in `strictNonReserved`.
// The non-reserved keywords are listed in `nonReserved`.
// These 2 together contain all the keywords.
strictNonReserved
    : ANTI
    | CROSS
    | EXCEPT
    | FULL
    | INNER
    | INTERSECT
    | JOIN
    | LEFT
    | NATURAL
    | ON
    | RIGHT
    | SEMI
    | SETMINUS
    | UNION
    | USING
    ;

nonReserved
    : ADD
    | AFTER
    | ALL
    | ALTER
    | ANALYZE
    | AND
    | ANY
    | ARCHIVE
    | ARRAY
    | AS
    | ASC
    | AT
    | AUTHORIZATION
    | BETWEEN
    | BOTH
    | BUCKET
    | BUCKETS
    | BY
    | CACHE
    | CASCADE
    | CASE
    | CAST
    | CHANGE
    | CHECK
    | CLEAR
    | CLUSTER
    | CLUSTERED
    | CODEGEN
    | COLLATE
    | COLLECTION
    | COLUMN
    | COLUMNS
    | COMMENT
    | COMMIT
    | COMPACT
    | COMPACTIONS
    | COMPUTE
    | CONCATENATE
    | CONSTRAINT
    | COST
    | CREATE
    | CUBE
    | CURRENT
    | CURRENT_DATE
    | CURRENT_TIME
    | CURRENT_TIMESTAMP
    | CURRENT_USER
    | DATA
    | DATABASE
    | DATABASES
    | DAY
    | DBPROPERTIES
    | DEFINED
    | DELETE
    | DELIMITED
    | DESC
    | DESCRIBE
    | DFS
    | DIRECTORIES
    | DIRECTORY
    | DISTINCT
    | DISTRIBUTE
    | DIV
    | DROP
    | ELSE
    | END
    | ESCAPE
    | ESCAPED
    | EXCHANGE
    | EXISTS
    | EXPLAIN
    | EXPORT
    | EXTENDED
    | EXTERNAL
    | EXTRACT
    | FALSE
    | FETCH
    | FILTER
    | FIELDS
    | FILEFORMAT
    | FIRST
    | FOLLOWING
    | FOR
    | FOREIGN
    | FORMAT
    | FORMATTED
    | FROM
    | FUNCTION
    | FUNCTIONS
    | GLOBAL
    | GRANT
    | GROUP
    | GROUPING
    | HAVING
    | HOUR
    | IF
    | IGNORE
    | IMPORT
    | IN
    | INDEX
    | INDEXES
    | INPATH
    | INPUTFORMAT
    | INSERT
    | INTERVAL
    | INTO
    | IS
    | ITEMS
    | KEYS
    | LAST
    | LATERAL
    | LAZY
    | LEADING
    | LIKE
    | LIMIT
    | LINES
    | LIST
    | LOAD
    | LOCAL
    | LOCATION
    | LOCK
    | LOCKS
    | LOGICAL
    | MACRO
    | MAP
    | MATCHED
    | MERGE
    | MINUTE
    | MONTH
    | MSCK
    | NAMESPACE
    | NAMESPACES
    | NO
    | NOT
    | NULL
    | NULLS
    | OF
    | ONLY
    | OPTION
    | OPTIONS
    | OR
    | ORDER
    | OUT
    | OUTER
    | OUTPUTFORMAT
    | OVER
    | OVERLAPS
    | OVERLAY
    | OVERWRITE
    | PARTITION
    | PARTITIONED
    | PARTITIONS
    | PERCENTLIT
    | PIVOT
    | PLACING
    | POSITION
    | PRECEDING
    | PRIMARY
    | PRINCIPALS
    | PROPERTIES
    | PURGE
    | QUERY
    | RANGE
    | RECORDREADER
    | RECORDWRITER
    | RECOVER
    | REDUCE
    | REFERENCES
    | REFRESH
    | RENAME
    | REPAIR
    | REPLACE
    | RESET
    | RESTRICT
    | REVOKE
    | RLIKE
    | ROLE
    | ROLES
    | ROLLBACK
    | ROLLUP
    | ROW
    | ROWS
    | SCHEMA
    | SECOND
    | SELECT
    | SEPARATED
    | SERDE
    | SERDEPROPERTIES
    | SESSION_USER
    | SET
    | SETS
    | SHOW
    | SKEWED
    | SOME
    | SORT
    | SORTED
    | START
    | STATISTICS
    | STORED
    | STRATIFY
    | STRUCT
    | SUBSTR
    | SUBSTRING
    | TABLE
    | TABLES
    | TABLESAMPLE
    | TBLPROPERTIES
    | TEMPORARY
    | TERMINATED
    | THEN
    | TO
    | TOUCH
    | TRAILING
    | TRANSACTION
    | TRANSACTIONS
    | TRANSFORM
    | TRIM
    | TRUE
    | TRUNCATE
    | TYPE
    | UNARCHIVE
    | UNBOUNDED
    | UNCACHE
    | UNIQUE
    | UNKNOWN
    | UNLOCK
    | UNSET
    | UPDATE
    | USE
    | USER
    | VALUES
    | VIEW
    | VIEWS
    | WHEN
    | WHERE
    | WINDOW
    | WITH
    | YEAR
    ;

// NOTE: If you add a new token in the list below, you should update the list of keywords
// in `docs/sql-keywords.md`. If the token is a non-reserved keyword,
// please update `ansiNonReserved` and `nonReserved` as well.

//==================================
// Start of the Fugue keywords list
//==================================

FILL: 'FILL';
TAKE: 'TAKE';
HASH: 'HASH';
RAND: 'RAND';
EVEN: 'EVEN';
PRESORT: 'PRESORT';
PERSIST: 'PERSIST';
BROADCAST: 'BROADCAST';
PARAMS: 'PARAMS';
PROCESS: 'PROCESS';
OUTPUT: 'OUTPUT';
OUTTRANSFORM: 'OUTTRANSFORM';
ROWCOUNT: 'ROWCOUNT';
CONCURRENCY: 'CONCURRENCY';
PREPARTITION: 'PREPARTITION';
ZIP: 'ZIP';
PRINT: 'PRINT';
TITLE: 'TITLE';
SAVE: 'SAVE';
APPEND: 'APPEND';
PARQUET: 'PARQUET';
CSV: 'CSV';
JSON: 'JSON';
SINGLE: 'SINGLE';

COLONEQUAL: ':=';
CHECKPOINT: 'CHECKPOINT';
WEAK: 'WEAK';
STRONG: 'STRONG';
DETERMINISTIC: 'DETERMINISTIC';

YIELD: 'YIELD';

CONNECT: 'CONNECT';

SAMPLE: 'SAMPLE';
SEED: 'SEED';

SUB: 'SUB';
CALLBACK: 'CALLBACK';

DATAFRAME: 'DATAFRAME';
FILE: 'FILE';

//================================
// End of the Fugue keywords list
//================================


//============================
// Start of the keywords list
//============================
ADD: 'ADD';
AFTER: 'AFTER';
ALL: 'ALL';
ALTER: 'ALTER';
ANALYZE: 'ANALYZE';
AND: 'AND';
ANTI: 'ANTI';
ANY: 'ANY';
ARCHIVE: 'ARCHIVE';
ARRAY: 'ARRAY';
AS: 'AS';
ASC: 'ASC';
AT: 'AT';
AUTHORIZATION: 'AUTHORIZATION';
BETWEEN: 'BETWEEN';
BOTH: 'BOTH';
BUCKET: 'BUCKET';
BUCKETS: 'BUCKETS';
BY: 'BY';
CACHE: 'CACHE';
CASCADE: 'CASCADE';
CASE: 'CASE';
CAST: 'CAST';
CHANGE: 'CHANGE';
CHECK: 'CHECK';
CLEAR: 'CLEAR';
CLUSTER: 'CLUSTER';
CLUSTERED: 'CLUSTERED';
CODEGEN: 'CODEGEN';
COLLATE: 'COLLATE';
COLLECTION: 'COLLECTION';
COLUMN: 'COLUMN';
COLUMNS: 'COLUMNS';
COMMENT: 'COMMENT';
COMMIT: 'COMMIT';
COMPACT: 'COMPACT';
COMPACTIONS: 'COMPACTIONS';
COMPUTE: 'COMPUTE';
CONCATENATE: 'CONCATENATE';
CONSTRAINT: 'CONSTRAINT';
COST: 'COST';
CREATE: 'CREATE';
CROSS: 'CROSS';
CUBE: 'CUBE';
CURRENT: 'CURRENT';
CURRENT_DATE: 'CURRENT_DATE';
CURRENT_TIME: 'CURRENT_TIME';
CURRENT_TIMESTAMP: 'CURRENT_TIMESTAMP';
CURRENT_USER: 'CURRENT_USER';
DATA: 'DATA';
DATABASE: 'DATABASE';
DATABASES: 'DATABASES' | 'SCHEMAS';
DAY: 'DAY';
DBPROPERTIES: 'DBPROPERTIES';
DEFINED: 'DEFINED';
DELETE: 'DELETE';
DELIMITED: 'DELIMITED';
DESC: 'DESC';
DESCRIBE: 'DESCRIBE';
DFS: 'DFS';
DIRECTORIES: 'DIRECTORIES';
DIRECTORY: 'DIRECTORY';
DISTINCT: 'DISTINCT';
DISTRIBUTE: 'DISTRIBUTE';
DROP: 'DROP';
ELSE: 'ELSE';
END: 'END';
ESCAPE: 'ESCAPE';
ESCAPED: 'ESCAPED';
EXCEPT: 'EXCEPT';
EXCHANGE: 'EXCHANGE';
EXISTS: 'EXISTS';
EXPLAIN: 'EXPLAIN';
EXPORT: 'EXPORT';
EXTENDED: 'EXTENDED';
EXTERNAL: 'EXTERNAL';
EXTRACT: 'EXTRACT';
FALSE: 'FALSE';
FETCH: 'FETCH';
FIELDS: 'FIELDS';
FILTER: 'FILTER';
FILEFORMAT: 'FILEFORMAT';
FIRST: 'FIRST';
FOLLOWING: 'FOLLOWING';
FOR: 'FOR';
FOREIGN: 'FOREIGN';
FORMAT: 'FORMAT';
FORMATTED: 'FORMATTED';
FROM: 'FROM';
FULL: 'FULL';
FUNCTION: 'FUNCTION';
FUNCTIONS: 'FUNCTIONS';
GLOBAL: 'GLOBAL';
GRANT: 'GRANT';
GROUP: 'GROUP';
GROUPING: 'GROUPING';
HAVING: 'HAVING';
HOUR: 'HOUR';
IF: 'IF';
IGNORE: 'IGNORE';
IMPORT: 'IMPORT';
IN: 'IN';
INDEX: 'INDEX';
INDEXES: 'INDEXES';
INNER: 'INNER';
INPATH: 'INPATH';
INPUTFORMAT: 'INPUTFORMAT';
INSERT: 'INSERT';
INTERSECT: 'INTERSECT';
INTERVAL: 'INTERVAL';
INTO: 'INTO';
IS: 'IS';
ITEMS: 'ITEMS';
JOIN: 'JOIN';
KEYS: 'KEYS';
LAST: 'LAST';
LATERAL: 'LATERAL';
LAZY: 'LAZY';
LEADING: 'LEADING';
LEFT: 'LEFT';
LIKE: 'LIKE';
LIMIT: 'LIMIT';
LINES: 'LINES';
LIST: 'LIST';
LOAD: 'LOAD';
LOCAL: 'LOCAL';
LOCATION: 'LOCATION';
LOCK: 'LOCK';
LOCKS: 'LOCKS';
LOGICAL: 'LOGICAL';
MACRO: 'MACRO';
MAP: 'MAP';
MATCHED: 'MATCHED';
MERGE: 'MERGE';
MINUTE: 'MINUTE';
MONTH: 'MONTH';
MSCK: 'MSCK';
NAMESPACE: 'NAMESPACE';
NAMESPACES: 'NAMESPACES';
NATURAL: 'NATURAL';
NO: 'NO';
NOT: 'NOT' | '!';
NULL: 'NULL';
NULLS: 'NULLS';
OF: 'OF';
ON: 'ON';
ONLY: 'ONLY';
OPTION: 'OPTION';
OPTIONS: 'OPTIONS';
OR: 'OR';
ORDER: 'ORDER';
OUT: 'OUT';
OUTER: 'OUTER';
OUTPUTFORMAT: 'OUTPUTFORMAT';
OVER: 'OVER';
OVERLAPS: 'OVERLAPS';
OVERLAY: 'OVERLAY';
OVERWRITE: 'OVERWRITE';
PARTITION: 'PARTITION';
PARTITIONED: 'PARTITIONED';
PARTITIONS: 'PARTITIONS';
PERCENTLIT: 'PERCENT';
PIVOT: 'PIVOT';
PLACING: 'PLACING';
POSITION: 'POSITION';
PRECEDING: 'PRECEDING';
PRIMARY: 'PRIMARY';
PRINCIPALS: 'PRINCIPALS';
PROPERTIES: 'PROPERTIES';
PURGE: 'PURGE';
QUERY: 'QUERY';
RANGE: 'RANGE';
RECORDREADER: 'RECORDREADER';
RECORDWRITER: 'RECORDWRITER';
RECOVER: 'RECOVER';
REDUCE: 'REDUCE';
REFERENCES: 'REFERENCES';
REFRESH: 'REFRESH';
RENAME: 'RENAME';
REPAIR: 'REPAIR';
REPLACE: 'REPLACE';
RESET: 'RESET';
RESTRICT: 'RESTRICT';
REVOKE: 'REVOKE';
RIGHT: 'RIGHT';
RLIKE: 'RLIKE' | 'REGEXP';
ROLE: 'ROLE';
ROLES: 'ROLES';
ROLLBACK: 'ROLLBACK';
ROLLUP: 'ROLLUP';
ROW: 'ROW';
ROWS: 'ROWS';
SCHEMA: 'SCHEMA';
SECOND: 'SECOND';
SELECT: 'SELECT';
SEMI: 'SEMI';
SEPARATED: 'SEPARATED';
SERDE: 'SERDE';
SERDEPROPERTIES: 'SERDEPROPERTIES';
SESSION_USER: 'SESSION_USER';
SET: 'SET';
SETMINUS: 'MINUS';
SETS: 'SETS';
SHOW: 'SHOW';
SKEWED: 'SKEWED';
SOME: 'SOME';
SORT: 'SORT';
SORTED: 'SORTED';
START: 'START';
STATISTICS: 'STATISTICS';
STORED: 'STORED';
STRATIFY: 'STRATIFY';
STRUCT: 'STRUCT';
SUBSTR: 'SUBSTR';
SUBSTRING: 'SUBSTRING';
TABLE: 'TABLE';
TABLES: 'TABLES';
TABLESAMPLE: 'TABLESAMPLE';
TBLPROPERTIES: 'TBLPROPERTIES';
TEMPORARY: 'TEMPORARY' | 'TEMP';
TERMINATED: 'TERMINATED';
THEN: 'THEN';
TO: 'TO';
TOUCH: 'TOUCH';
TRAILING: 'TRAILING';
TRANSACTION: 'TRANSACTION';
TRANSACTIONS: 'TRANSACTIONS';
TRANSFORM: 'TRANSFORM';
TRIM: 'TRIM';
TRUE: 'TRUE';
TRUNCATE: 'TRUNCATE';
TYPE: 'TYPE';
UNARCHIVE: 'UNARCHIVE';
UNBOUNDED: 'UNBOUNDED';
UNCACHE: 'UNCACHE';
UNION: 'UNION';
UNIQUE: 'UNIQUE';
UNKNOWN: 'UNKNOWN';
UNLOCK: 'UNLOCK';
UNSET: 'UNSET';
UPDATE: 'UPDATE';
USE: 'USE';
USER: 'USER';
USING: 'USING';
VALUES: 'VALUES';
VIEW: 'VIEW';
VIEWS: 'VIEWS';
WHEN: 'WHEN';
WHERE: 'WHERE';
WINDOW: 'WINDOW';
WITH: 'WITH';
YEAR: 'YEAR';
//============================
// End of the keywords list
//============================

EQUAL: '=';
DOUBLEEQUAL: '==';

NSEQ: '<=>';
NEQ : '<>';
NEQJ: '!=';
LT  : '<';
LTE : '<=' | '!>';
GT  : '>';
GTE : '>=' | '!<';

PLUS: '+';
MINUS: '-';
ASTERISK: '*';
SLASH: '/';
PERCENT: '%';
DIV: 'DIV';
TILDE: '~';
AMPERSAND: '&';
PIPE: '|';
CONCAT_PIPE: '||';
HAT: '^';

STRING
    : '\'' ( ~('\''|'\\') | ('\\' .) )* '\''
    | '"' ( ~('"'|'\\') | ('\\' .) )* '"'
    ;

BIGINT_LITERAL
    : DIGIT+ 'L'
    ;

SMALLINT_LITERAL
    : DIGIT+ 'S'
    ;

TINYINT_LITERAL
    : DIGIT+ 'Y'
    ;

INTEGER_VALUE
    : DIGIT+
    ;

EXPONENT_VALUE
    : DIGIT+ EXPONENT
    | DECIMAL_DIGITS EXPONENT {self.isValidDecimal()}?
    ;

DECIMAL_VALUE
    : DECIMAL_DIGITS {self.isValidDecimal()}?
    ;

DOUBLE_LITERAL
    : DIGIT+ EXPONENT? 'D'
    | DECIMAL_DIGITS EXPONENT? 'D' {self.isValidDecimal()}?
    ;

BIGDECIMAL_LITERAL
    : DIGIT+ EXPONENT? 'BD'
    | DECIMAL_DIGITS EXPONENT? 'BD' {self.isValidDecimal()}?
    ;

IDENTIFIER
    : (LETTER | DIGIT | '_')+
    ;

BACKQUOTED_IDENTIFIER
    : '`' ( ~'`' | '``' )* '`'
    ;

fragment DECIMAL_DIGITS
    : DIGIT+ '.' DIGIT*
    | '.' DIGIT+
    ;

fragment EXPONENT
    : 'E' [+-]? DIGIT+
    ;

fragment DIGIT
    : [0-9]
    ;

fragment LETTER
    : [A-Z]
    | {not self.allUpperCase}? [a-z]
    ;

SIMPLE_COMMENT
    : ('--' | '//' | '#') ('\\\n' | ~[\r\n])* '\r'? '\n'? -> channel(HIDDEN)
    ;

BRACKETED_COMMENT
    : '/*' {not self.isHint()}? (BRACKETED_COMMENT|.)*? '*/' -> channel(HIDDEN)
    ;

WS
    : [ \r\n\t]+ -> channel(HIDDEN)
    ;

// Catch-all for anything we can't recognize.
// We use this to be able to ignore and recover all the text
// when splitting statements with DelimiterLexer
UNRECOGNIZED
    : .
    ;
