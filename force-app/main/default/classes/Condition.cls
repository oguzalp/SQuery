public virtual class Condition implements IQueryable {
    
    
    String sql {get;private set;}

    protected String seperator {get; protected set;}
    
    public List<Condition> conditions {get;protected set;}

    public Condition(){
        this.conditions = new List<Condition>();
    }
    
    public Condition(String seperator){
        this();
        this.seperator = seperator;        
    }
    
    
    public virtual Condition add(Condition c){
		this.conditions.add(c);
		return this;        
    }
        
    public virtual String toSoql(){
        sql = '';
        if(this.conditions.size() > 1){
			sql += '(';
            List<String> allConditionsSql = new List<String>();
            for(Condition cn : this.conditions){
                allConditionsSql.add(cn.toSoql());
            }
            sql += String.join(allConditionsSql, ' ' + this.seperator + ' ');
            sql += ')';
        }else{
       		sql = this.conditions.get(0).toSoql();	     
        }
        return sql;
    }
}