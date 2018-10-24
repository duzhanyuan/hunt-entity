/*
 * Entity - Entity is an object-relational mapping tool for the D programming language. Referring to the design idea of JPA.
 *
 * Copyright (C) 2015-2018  Shanghai Putao Technology Co., Ltd
 *
 * Developer: HuntLabs.cn
 *
 * Licensed under the Apache-2.0 License.
 *
 */
 
module hunt.entity.EntityFieldManyToMany;

import hunt.entity;

import hunt.logging;



class EntityFieldManyToMany(T : Object, F : Object = T,string MAPPEDBY = "") : EntityFieldObject!(T,F) {


    private ManyToMany _mode;
    private string _primaryKey;
    // private string _joinColumn;
    private string _findString;
    private T[][string] _decodeCache;


    this(EntityManager manager, string fileldName, string primaryKey, string tableName, ManyToMany mode, F owner, bool isMainMapped ) {
        // logDebug("ManyToMany(%s,%s) not main mapped ( %s , %s , %s , %s ,%s )".format(T.stringof,F.stringof,fileldName,primaryKey,tableName,mode,isMainMapped));
        super(manager, fileldName, "", tableName, null, owner);
        _isMainMapped = isMainMapped;
        init(primaryKey, mode, owner);
    }

    this(EntityManager manager, string fileldName, string primaryKey, string tableName, ManyToMany mode, F owner, 
            bool isMainMapped ,JoinTable joinTable , JoinColumn jc  ,InverseJoinColumn ijc ) {
        // logDebug("ManyToMany(%s,%s) main mapped( %s , %s , %s , %s ,%s , %s , %s , %s )".format(T.stringof,F.stringof,fileldName,primaryKey,tableName,mode,isMainMapped,joinTable,jc,ijc));
        super(manager, fileldName, "", tableName, null, owner);
        _isMainMapped = isMainMapped;
        _joinColumn = jc.name;
        _inverseJoinColumn = ijc.name;
        _joinTable = joinTable.name;
        init(primaryKey, mode, owner);
    }

    private void init(string primaryKey,  ManyToMany mode, F owner) {
        _mode = mode;       
        _enableJoin = _mode.fetch == FetchType.EAGER;    
        _primaryKey = primaryKey;
        static if(MAPPEDBY != "")
        {
            if(!_isMainMapped )
            {
                _inverseJoinColumn =  hunt.entity.utils.Common.getInverseJoinColumn!(T,MAPPEDBY).name;
                _joinColumn =   hunt.entity.utils.Common.getJoinColumn!(T,MAPPEDBY).name;
                _joinTable =   hunt.entity.utils.Common.getJoinTableName!(T,MAPPEDBY);
            }
        }
        
        // logDebug("----(%s , %s ,%s )".format(_joinColumn,_inverseJoinColumn,_joinTable));
        
        initJoinData();
        initFindStr();
    }

    private void initJoinData() {
        _joinSqlData = new JoinSqlBuild(); 
        _joinSqlData.tableName = _joinTable;
        if(_isMainMapped)
            _joinSqlData.joinWhere = _entityInfo.getTableName() ~ "." ~ _entityInfo.getPrimaryKeyString ~ " = " ~ _joinTable ~ "." ~ _inverseJoinColumn;
        else
            _joinSqlData.joinWhere = _entityInfo.getTableName() ~ "." ~ _entityInfo.getPrimaryKeyString ~ " = " ~ _joinTable ~ "." ~ _joinColumn;
        _joinSqlData.joinType = JoinType.LEFT;
        // foreach(value; _entityInfo.getFields()) {
        //     _joinSqlData.columnNames ~= value.getSelectColumn();
        // }
        // logDebug("many to many join sql : %s ".format(_joinSqlData));
    }

    override public string getSelectColumn() {
        return "";
    }


    private void initFindStr() {
        _findString = "SELECT ";
        string[] el;
        foreach(k,v; _entityInfo.getFields()) {
            if (v.getSelectColumn() != "")
                el ~= " "~v.getSelectColumn();
        }
        foreach(k,v; el) {
            _findString ~= v;
            if (k != el.length -1)
                _findString ~= ",";
        }
        _findString ~= " FROM "~_joinTable~" WHERE " ~ _joinTable ~"."~_joinColumn~" = ";
    }

    public string getPrimaryKey() {return _primaryKey;}
    public ManyToMany getMode() {return _mode;}



    public T[] deSerialize(Row[] rows, int startIndex, bool isFromManyToOne) {
        T[] ret;
        if (_mode.fetch == FetchType.LAZY)
            return ret;
        logDebug("-----do do do ---");
        T singleRet;
        long count = -1;
        if (!isFromManyToOne) {
            foreach(value; rows) {
                singleRet = _entityInfo.deSerialize([value], count);
                if (singleRet)
                    ret ~= Common.sampleCopy(singleRet);
            }
        }
        else {
            string joinValue = getJoinKeyValue(rows[startIndex]);
            if (joinValue == "")
                return ret;
            T[] rets = getValueByJoinKeyValue(joinValue);
            foreach(value; rets) {
                ret ~= Common.sampleCopy(value);
            }
        }
        return ret;
    }

    private string getJoinKeyValue(Row row) {
        RowData data = row.getAllRowData(getTableName());
        if (data is null)
            return "";
        RowDataS rd = data.getData(_primaryKey);
        if (rd is null)
            return "";
        return rd.value;
    }

    private T[] getValueByJoinKeyValue(string key) {
        if (key in _decodeCache)
            return _decodeCache[key];

        T[] ret;
        T singleRet;
        auto stmt = _manager.getSession().prepare(_findString~key);
		auto res = stmt.query();
        long count = -1;
        foreach(value; res) {
            singleRet = _entityInfo.deSerialize([value], count);
            if (singleRet)
                ret ~=  singleRet;
        }
        _decodeCache[key] = ret;
        return _decodeCache[key];
    }

    public void setMode(ManyToMany mode) {
        _mode = mode;
        _enableJoin = _mode.fetch == FetchType.EAGER;    
    }

    public LazyData getLazyData(Row row) {
        // logDebug("--- MappedBy : %s , row : %s ".format(_mode.mappedBy,row));

        RowData data = row.getAllRowData(getTableName());
        // logDebug("---data : %s , _primaryKey : %s ".format(data,_primaryKey));
        if (data is null)
            return null;
        if (data.getData(_primaryKey) is null)
            return null;
        // logDebug("---------------------");
        LazyData ret = new LazyData(_mode.mappedBy, data.getData(_primaryKey).value);
        return ret;
    }



}