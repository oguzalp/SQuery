/*MIT License

Copyright (c) 2018 ogzalp

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

public virtual class SQuery implements IQueryable{
    private Boolean enforceFLS;
    
    private Schema.DescribeSObjectResult sobjectResult;
    private Map<String,Schema.SObjectField> sobjectFields; 
    private Map<String,Schema.DescribeFieldResult> sObjectlocalFields;
    //private Map<String,Schema.SObjectType> childRelationShips;
    private Set<String> fields;
    private Set<String> parentFields;
    private Integer queryLimit;
    private Integer offSetValue;
    //private String orderState;
    private Condition whereState;
    private String additionalWhereClause;
    private String queryState;
    private String soql;
    private String objectName;
    private String forView = '';
    private String forReference = '';
    private String forUpdate = '';

    private List<SQuery> subQueries; 
    private List<OrderBy> orderBys;
    public Schema.SObjectType objectType {get;set;}
    
    /*
        Initialize variables;
    */
    public SQuery(){
        this.fields = new Set<String>();
        this.parentFields = new Set<String>();
        this.subQueries = new List<SQuery>();
        //this.childRelationShips = new Map<String,Schema.SObjectType>();
        this.orderBys = new List<OrderBy>();
        this.enforceFLS = false;
    }

    public SQuery(String objectName){
        this();
         // Get Schema.SObjectType
        Map<String, Schema.SObjectType> globalDescribe =
            Schema.getGlobalDescribe();

        this.objectName = addNameSpace(objectName);
        System.debug('objectName==>'+this.objectName);
        this.objectType = globalDescribe.get(this.objectName);
		System.debug('objectType===>'+objectType);
        if (null == this.objectType) {

            throw new SQueryException('Cannot find corresponding ' +
                    'SObject type from the SObject name ' + this.objectName);
        } 

        this.sobjectResult = objectType.getDescribe();
        this.sobjectFields = sobjectResult.fields.getMap();
        setLocalNamesOfFieldsToMap();
    }

    public SQuery(Schema.SObjectType objectType) {
        this();
        this.objectType = objectType;
        this.sobjectResult = objectType.getDescribe();
        this.objectName = sobjectResult.getName(); 
        this.sobjectFields = sobjectResult.fields.getMap();
        setLocalNamesOfFieldsToMap(); 
    }

    /*
        this constructor should be used for only SubQueries
    */
    public Squery(Schema.SObjectType objectType,String relationName){
        this();
        String childRelName = addNamespace(relationName);
        this.objectType = objectType;
        this.sobjectResult = objectType.getDescribe(); 
        this.sobjectFields = sobjectResult.fields.getMap();
        this.objectName = childRelName;
        setLocalNamesOfFieldsToMap();       
    }
    
    public SQuery enforceFLS(){
        this.enforceFLS = true;
        return this;
    }

    public SQuery addFields(List<String> fields){
        for(String fn: fields){
            this.addField(fn);
        } 
        //this.fields = new Set<String>(fields);
        return this;
    }
    //, comma seperated fields
    public SQuery addFields(String fields){
        if(fields.contains(',')){
            List<String> fieldList = fields.split(',');
            this.addFields(fieldList);
        }
        return this;
    }

    public SQuery addField(String fieldName){        
        this.fields.add(getQualifiedFieldName(fieldName));
        return this;
    }

    public SQuery selectAll(){

        for( Schema.SObjectField sobjectField: this.sobjectFields.values()){
            Schema.DescribefieldResult fieldResult = sobjectField.getDescribe();
            if(fieldResult.isAccessible()){
                this.fields.add(fieldResult.getName());
            }  
        }
        return this;
    }

	
    public SQuery addSubQuery(SQuery subQuery){
        if(subQuery!=null && String.isNotBlank(subQuery.objectName)){
            this.subQueries.add(subQuery);
            return this;
        }else{
            throw new SQueryException( ' Invalid SubQuery object! ' );
        }
        
    }

    public SQuery addParentFields(List<String> parentFields){
        for(String fn: parentFields){
            this.addParentField(fn);
        } 
        return this;  
    }

    public SQuery addParentField(String parentFieldName){
        String qualifiedName = getQualifiedParentName(parentFieldName);
        System.debug('qualifiedParentName===>'+qualifiedName);
        this.parentFields.add(parentFieldName);
        return this;
    }

    
    public Squery addCondition(Condition c){
        this.whereState = c;
        return this;
    }

    public SQuery addCondition(String additionalWhereStatement){
        this.additionalWhereClause = additionalWhereStatement;
        return this;
    }

    public SQuery getRecordById(String recordId){
        this.addCondition( new Field('Id').equals( recordId ));
        return this;        
    }

    public SQuery getRecordsByIds(List<String> idSet){
        this.addCondition( new Field('Id').isIN(idSet) );
        return this;
    }

    
    public String getQualifiedParentName(String fieldName){
        String temp = fieldName;  
        SObjectType objtype;
        List<String> allFields = new List<String>();
        if(fieldName.contains('.')){         
             while (temp.contains('.')) {
                if(objtype == null){ objtype = this.objectType; } 
                //System.debug('ObjectType===>'+objtype);
                String first = temp.subStringBefore('.');
                //System.debug('first===>'+first);
                String objField = translateParentField(first);
                //System.debug('objField===>'+objField);
                DescribeFieldResult dfr = getFieldDescribeByName(objtype,objField); 

                allFields.add(reverseParentField(dfr.getName()));

                if(! dfr.getReferenceTo().isEmpty()){
                    objtype = dfr.getReferenceTo()[0];
                }
                temp = temp.subStringAfter('.');
                if(!temp.contains('.')){
                   allFields.add(getFieldDescribeByName(objtype,temp).getName());
                }
                //System.debug('last temp===>'+temp);
            }
            return String.join(allFields,'.');       
         }else{
             return getFieldDescribeByName(this.objectType,fieldName).getName();
         }
       
    }

    private DescribeFieldResult getFieldDescribeByName(SobjectType stype,String fieldApi){
       return stype.getDescribe().fields.getMap().get(fieldApi.toLowerCase()).getDescribe();
    }

    private static String translateParentField(String parentName) {
        // translate the reference name
        if (parentName.endsWithIgnoreCase('__r')) {
            parentName = parentName.removeEnd('__r') + '__c';
        } else if (parentName.endsWithIgnoreCase('Id')) {
            parentName = parentName;
        } else {
            parentName = parentName + 'Id';
        }

        return parentName;
    }

    private static String reverseParentField(String parentField){
           if(parentField.endsWithIgnoreCase('__c')){
                return parentField.removeEnd('__c') + '__r';
            }else if(parentField.endsWithIgnoreCase('Id')){
                return parentField.removeEnd('Id');
            }
            else{
                return parentField;
            }         
    }


    public SQuery orderBy(String fieldName, SortDirection direction){

        orderBys.add(new OrderBy(
                getQualifiedFieldName(fieldName), 
                direction
        ));
        
        return this;
    }

    public SQuery setLimit(Integer ql){
        this.queryLimit = ql;
        return this;
    }

    public SQuery offset(Integer offSetValue){
        this.offSetValue = offSetValue;
        return this;
    }

    public SQuery forView(){
        this.forView = ' FOR VIEW';
        return this;
    }

    public SQuery forUpdate(){
        this.forUpdate = ' FOR UPDATE';
        return this;
    }

    public SQuery forReference(){
        this.forReference = ' FOR REFERENCE';
        return this;
    }

    public List<SObject> runQuery(){
        try{
            return new List<SObject>( Database.query(this.toSoql() ));
            
        } catch(Exception ex) {
            throw new SQueryException(ex.getMessage());
        }  
    }
    
    private void setLocalNamesOfFieldsToMap(){
        if(sObjectlocalFields == null || sObjectlocalFields.isEmpty()){
            sObjectlocalFields = new Map<String,Schema.DescribeFieldResult>();
            for(String fname : this.sobjectFields.keyset()){
                String localName =  sObjectFields.get(fname).getDescribe().getLocalName();
                sObjectlocalFields.put(localName.toLowerCase(),sObjectFields.get(fname).getDescribe());
            }
        }
    }


    private String getQualifiedFieldName(String fieldName){
        String lowerFieldName = fieldName.toLowerCase();
        if(sObjectlocalFields.containsKey(lowerFieldName)){
            //non-packaged name
            return sObjectlocalFields.get(lowerFieldName).getName();  
        }else if(this.sobjectFields.containsKey(lowerFieldName)){
            //packaged name 
            return fieldName;
        }else{
           
            throw new SQueryException( fieldName + ' field can not be found in that sobject');
        }
    }

    public static String addNameSpace(String obj){
        if(String.isEmpty(namespace)){
            return obj;
        }
        
        if (obj.countMatches('__') == 1) {

            obj = namespace + '__' + obj;
        
        } else if (obj.endsWithIgnoreCase('__s') && obj.countMatches('__') == 2) {
            //If it is a location field            
            obj = namespace + obj;
        }

        return obj;
    }
    
    private static String namespace{
        get{
            if(namespace == null){
                List<String> qualifiedClassName = SQuery.class.getName().split('\\.');
                if(qualifiedClassName.size() == 2 ){
                    return qualifiedClassName.get(0);
                }else{
                    return '';
                }   
            }else{
                return namespace;
            } 
        }
    }

    public String toSoqL(){

        String formatString = 'SELECT {0} FROM {1}';

        if(this.fields.isEmpty()){
           this.fields = new Set<String>{'Id'};
        }

        if(!this.parentFields.isEmpty()){
           this.fields.addAll(this.parentFields);
        }

        if(this.enforceFLS){
           setSharingRules();
        }
       //add sub Query
        if(!this.subQueries.isEmpty()){

           for(SQuery sq: this.subQueries){
               String temp = '(';
               temp += sq.toSoql();
               temp += ')'; 
               this.fields.add(temp);
           }
        }

        List<String> args = new String[]{
           String.join(new List<String>(this.fields),','),
           this.objectName
        };
           
        soql = String.format(formatString,args);

        if(this.whereState != null){
            soql += ' WHERE ' + whereState.toSoql();     
        }

        if(this.whereState != null && this.additionalWhereClause!=null){
            soql += ' ' + this.additionalWhereClause;
        }

        if(this.whereState == null && this.additionalWhereClause!=null){
           soql += ' WHERE ' + this.additionalWhereClause;
        }
        
        if( !this.orderBys.isEmpty() ){
           //soql += this.orderState;
           soql += ' ORDER BY ';
           List<String> orderByStates = new List<String>();
           for(OrderBy oby : this.orderBys){
               orderByStates.add(oby.toSoql());
           }
           soql += String.join(orderByStates,',');
        }

        if(this.queryLimit!=null){
           soql += ' LIMIT ' + String.valueOf(queryLimit);
        }

        if(this.offSetValue != null){
           soql += ' OFFSET ' + String.valueOf(offSetValue);
        }

        if(this.forReference != null ){
            soql += this.forReference;
        }

        if(this.forView != null ){
            soql += this.forView;
        }

        if(this.forUpdate != null ){
            soql += this.forUpdate;
        }

        System.debug(' SOQL QUERY === ' + soql);

       return soql; 
    
    }

    private void setSharingRules(){
        if(! objectType.getDescribe().isAccessible()){
            throw new SQueryException('Permission Denied: cannot read ' + objectType.getDescribe().getName() + ' object');
        }
        Set<String> accessibleFields = new Set<String>();
        for(String fn : this.fields){
            String fnLower = fn.toLowerCase();
            if(sobjectFields.containsKey(fnLower)){
                Schema.DescribeFieldResult fresult = sobjectFields.get(fnLower).getDescribe();
                if(fresult.isAccessible()){
                    accessibleFields.add(fresult.getName());
                }else{
                    throw new SQueryException('Permission Denied: cannot read ' + fresult.getName() + ' field');
                }
            }
        }
    }

    private String getQualifiedSObjectName(){
        return this.objectName;
    }

    private String getReferenceFieldName(String fieldRel){
        if(fieldRel.endsWithIgnoreCase('__r')){
           return fieldRel.removeEnd('__r') + '__c';    
        }else{
            return fieldRel;
        }
    }

    public enum SortDirection{
        ASCENT,
        DESCENT,
        ASC_NULL_LAST,
        DESC_NULL_LAST
    }

    class OrderBy implements IQueryable{

        public String fieldName {get;set;}
        public SortDirection direction {get;set;}
        public OrderBy( String fieldName, SortDirection drc ){
            this.fieldName = fieldName;
            this.direction = drc;
        }

        public String toSoql(){ 
            String orderString = this.fieldName;

            if( direction == SortDirection.ASCENT ){
                orderString += ' ASC';
            }else if( direction == SortDirection.DESCENT){
               orderString += ' DESC'; 
            }else if(direction == SortDirection.ASC_NULL_LAST){
                orderString += ' ASC NULLS LAST';   
            }else if(direction == SortDirection.DESC_NULL_LAST){
               orderString += ' DESC NULLS LAST'; 
            }

            return orderString;
        }
    }


    public class SQueryException extends Exception { }
}