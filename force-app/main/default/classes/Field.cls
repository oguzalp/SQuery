public class Field extends Condition {
	
    public String field {get;private set;} 
    protected Operator operant {get;private set;}

    public Object value {get;private set;}
  
    public Field(String field){
        this.field = field;     
    }
    
    public Field(SObjectField field){
        this.field = field.getDescribe().getName();
    }
    
    public Field equals(Object value){
        this.operant = Operator.EQUALS;
        this.value = value;
        return this;  
    }
    
    public Field notEquals(Object value){
        this.operant = Operator.NOT_EQUALS;
        this.value = value;
        return this;  
    }

    public Field lessThan(Object value){
        this.operant = Operator.LESS_THAN;
        this.value = value;
        return this;  
    }
    public Field lessThanOrEqual(Object value){
        this.operant = Operator.LESS_THAN_OR_EQUAL;
        this.value = value;
        return this;  
    }

    public Field greaterThan(Object value){
        this.operant = Operator.GREATER_THAN;
        this.value = value;
        return this;  
    }

    public Field greaterThanOrEqual(Object value){
        this.operant = Operator.GREATER_THAN_OR_EQUAL;
        this.value = value;
        return this;  
    }

    public Field isLike(Object value){
        this.operant = Operator.ISLIKE;
        this.value = value;
        return this;
    }

    public Field startWith(Object value){
        this.operant = Operator.STARTS_WITH;
        this.value = value;
        return this;  
    }

    public Field endWith(Object value){
        this.operant = Operator.ENDS_WITH;
        this.value = value;
        return this;  
    }

    public Field contains(Object value){
        this.operant = Operator.CONTAINS;
        this.value = value;
        return this;  
    }

    public Field includes(Object value){
        this.operant = Operator.INCLUDES;
        this.value = value;
        return this;  
    }

    public Field excludes(Object value){
        this.operant = Operator.EXCLUDES;
        this.value = value;
        return this;  
    }

    public Field isIN(Object value){
        this.operant = Operator.IS_IN;
        this.value = value;
        return this;  
    }

    public Field notIN(Object value){
        this.operant = Operator.NOT_IN;
        this.value = value;
        return this;  
    }
    
    public Field isNull() {
		this.operant = Operator.EQUALS;
        this.value = NULL;
		return this;
	}

	public Field isNotNull() {
		this.operant = Operator.NOT_EQUALS;
        this.value = NULL;
		return this;
	}
    
    public override String toSoql(){

        String whereSql='';

        if (operant == Operator.EQUALS) {
            whereSql = field + ' = ' + objectValueToSoqlLiteral(value);
        }else if( operant == Operator.NOT_EQUALS ){
            whereSql = field + ' != ' + objectValueToSoqlLiteral(value); 
        }else if( operant == Operator.LESS_THAN ){
            whereSql = field + ' < ' + objectValueToSoqlLiteral(value);
        }else if( operant == Operator.LESS_THAN_OR_EQUAL ){
            whereSql = field + ' <= ' + objectValueToSoqlLiteral(value);
        }else if( operant == Operator.GREATER_THAN ){
            whereSql = field + ' > ' + objectValueToSoqlLiteral(value);
        }else if( operant == Operator.GREATER_THAN_OR_EQUAL ){
            whereSql = field + ' >= ' + objectValueToSoqlLiteral(value);
        }
        else if( operant == Operator.ISLIKE ){
            String param = String.valueOf(value);
            whereSql = field + ' LIKE ' + '\'' + param + '\'';
        }
        else if( operant == Operator.ENDS_WITH ){
            whereSql = field + ' LIKE ' +  '\'%' + String.escapeSingleQuotes(String.valueOf(value)) + '\'';
        }
        else if( operant == Operator.STARTS_WITH ){
            whereSql = field + ' LIKE ' +  '\'' + String.escapeSingleQuotes(String.valueOf(value)) + '%\'';
        }
        else if( operant == Operator.CONTAINS ){
            whereSql = field + ' LIKE ' +  '\'%' + String.escapeSingleQuotes(String.valueOf(value)) + '%\'';
        }else if( operant == Operator.INCLUDES){
            whereSql = field + ' INCLUDES (' + objectValueToSoqlLiteral(value) + ')';
        }else if( operant == Operator.EXCLUDES){
            whereSql = field + ' EXCLUDES (' + objectValueToSoqlLiteral(value) + ')';
        }else if( operant == Operator.IS_IN){
            whereSql = field + ' IN (' + objectValueToSoqlLiteral(value) + ')';
        }else if( operant == Operator.NOT_IN){
            whereSql = field + ' NOT IN (' + objectValueToSoqlLiteral(value) + ')';
        }else{
            return null; //TODO: throw Unsupported Operator
        }

        return whereSql;
    
    }

    
    
    public static String objectValueToSoqlLiteral(Object val){
        String returnValue = '';
        if(val == null){
           returnValue += 'NULL';   
        }else if(val instanceof String || 
                val instanceof ID ){
            returnValue += '\'' + String.escapeSingleQuotes(String.valueOf(val)) + '\'';
                    
        }else if(val instanceOf Boolean ||
                val instanceOf Integer || 
                val instanceOf Long    || 
                val instanceOf Double  || 
                val instanceOf Decimal){

           returnValue += val;

        }else if(val instanceof Date){

            returnValue += String.valueOf((Date)val).trim();

        }else if(val instanceof Datetime){
            DateTime dtime = (Datetime)val;
            Datetime dGmt = Datetime.newInstanceGmt(dtime.year(),dtime.month(),dtime.day(),dtime.hour(),dtime.minute(),dtime.second());
            returnValue += JSON.serialize(dGmt).remove('"');
        }
        else if(val instanceof List<String> || val instanceof List<Id>){
            List<String> vals = (List<String>)val;
            returnValue += prepareObjectValuesAsString(vals);           
        }else if(val instanceof Set<String>){      
            List<String> vals = new List<String>((Set<String>)val);
            returnValue += prepareObjectValuesAsString(vals);
        }else if(val instanceof Set<Id>){
            List<String> vals = (List<String>)new List<Id>((Set<Id>)val);
            returnValue += prepareObjectValuesAsString(vals);
        }
        else if(val instanceof DateLiteral){

            returnValue += ((DateLiteral)val).name();

        }else if(val instanceOf SQuery){
            SQuery sq =(SQuery)val;
            returnValue += sq.toSoql();
        }
        else{
            throw new SQuery.SQueryException('Object value types must be null|primitive|SQuery types or array of primitive types');
        }
        
        return returnValue;
    }

    private static String prepareObjectValuesAsString(List<String> values){
        if(values == null || values.isEmpty()) return '';
        List<String> vals = new List<String>();
        for(String v : values){
            vals.add( '\'' + String.escapeSingleQuotes(v) + '\'');
        }
        return String.join(vals, ',');
    }

    public enum Operator {
        EQUALS,
        NOT_EQUALS,
        LESS_THAN,
        LESS_THAN_OR_EQUAL,
        GREATER_THAN,
        GREATER_THAN_OR_EQUAL,
        ISLIKE,
        STARTS_WITH,
        ENDS_WITH,
        CONTAINS,
        INCLUDES,
        EXCLUDES,
        IS_IN,    
        NOT_IN   
    }
}