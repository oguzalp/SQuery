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
    private Set<String> fields;
    private Set<String> parentFields;
    private Integer queryLimit;
    private Integer offSetValue;
    private Condition whereState;
    private List<Condition> conditions; 
    private String additionalWhereClause;
    private String queryState;
    private String soql;
    private String objectName;
    private String forView = '';
    private String forReference = '';
    private String forUpdate = '';

    private List<SQuery> subQueries;
    private Set<String> subQueryAsFields; 
    private List<OrderBy> orderBys;
    public Schema.SObjectType objectType {get;set;}

    private List<String> qualifiedParentFields;
    
    /*
        Initialize variables;
    */
    public SQuery(){
        this.qualifiedParentFields = new List<String>();
        this.fields = new Set<String>();
        this.parentFields = new Set<String>();
        this.subQueries = new List<SQuery>();
        this.subQueryAsFields = new Set<String>();
        this.conditions = new List<Condition>();
        this.orderBys = new List<OrderBy>();
        this.enforceFLS = false;
    }

    public SQuery(String objectName){
        this();

        Map<String, Schema.SObjectType> globalDescribe =
            Schema.getGlobalDescribe();

        this.objectName = addNameSpace(objectName);

        this.objectType = globalDescribe.get(this.objectName);

        if (null == this.objectType) {

            throw new SQueryException('Cannot find corresponding ' +
                    'SObject type from the SObject ' + this.objectName);
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
    
    public Map<String,Schema.DescribeFieldResult> getLocalFields(){
        return this.sObjectlocalFields;
    }
    
    public SQuery enforceFLS(){
        this.enforceFLS = true;
        return this;
    }

    public SQuery addFields(List<String> fields){
        if(fields!=null && !fields.isEmpty()){
            for(String fn: fields){
                 this.addField(fn.trim());
            } 
        }
        //this.fields = new Set<String>(fields);
        return this;
    }
    //, comma seperated fields
    public SQuery addFields(String fields){
        if(String.isBlank(fields)) return this;

        if(fields.contains(',')){
            List<String> fieldList = fields.split(',');
            this.addFields(fieldList);
        }else{
           this.addField(fields.trim()); 
        }
        return this;
    }

    public SQuery addField(String fieldName){
        if(String.isNotBlank(fieldName)){
            this.fields.add(getQualifiedFieldName(fieldName.trim()));
        }        
        return this;
    }

    public SQuery setFieldSet(String fieldSetName){

        if(this.sobjectResult == null) throw new SQueryException('object describe result can not be blank');
        Map<String,Schema.FieldSet> fieldSets = this.sobjectResult.fieldsets.getMap();
        if(!fieldSets.containsKey(fieldSetName)){
            throw new SQueryException('the given field set can not be found.');
        }
        Schema.FieldSet fset = fieldSets.get(fieldSetName);
        for(Schema.FieldSetMember fm : fset.getFields()){
           String fieldName = fm.getFieldPath();
           if(fieldName.contains('\\.')){
               this.addParentField(fieldName);
           }else{
               this.fields.add(fieldName);
           } 
        }
        return this;
    }

    public SQuery selectAll(){

        for(Schema.SObjectField sobjectField: this.sobjectFields.values()){
            Schema.DescribefieldResult fieldResult = sobjectField.getDescribe();
            if(this.enforceFLS && fieldResult.isAccessible()){
                this.fields.add(fieldResult.getName());
            }else{
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
        if(parentFields!=null && !parentFields.isEmpty()){
            for(String fn: parentFields){
                this.addParentField(fn);
            } 
        }
        return this;  
    }

    /**
     *  Comma delimited field list
     */
    public SQuery addParentFields(String parentFields){
        if(String.isBlank(parentFields)) return this;
        if(parentFields.contains(',')){
            List<String> fieldList = parentFields.split(',');
            this.addParentFields(fieldList);
        }else{
           this.addParentField( parentFields.trim() ); 
        }
        return this;
    }

    public SQuery addParentField(String parentFieldName){
        if(String.isNotBlank(parentFieldName)){
            String qualifiedName = getQualifiedParentFieldNames(this.objectType, parentFieldName.trim());
            this.parentFields.add(qualifiedName);
            //!important, Empty the parentfield list for the other parent fields!!
            this.qualifiedParentFields = new List<String>();
        } 
        return this;
    }

    
    public Squery addCondition(Condition c){
        this.conditions.add(c);
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

    public SQuery getRecordById(List<Id> idSet){
        this.addCondition( new Field('Id').isIN(idSet) );
        return this;
    }

    //object type, comma seperated fieldNames
    private String getQualifiedParentFieldNames(SObjectType objType,String fieldNames){        
        if(objType == null) { 
            throw new SQuery.SQueryException('Sobject type was not specified!');
        }
        try{
            DescribeFieldResult dfr;
            if(fieldNames.contains('.')){
                String first =  fieldNames.subStringBefore('.');
                String remained = fieldNames.subStringAfter('.');
                //Assuming that the field has no namespace prefix.Otherwise it will throw an error.
                String localFieldName = translateParentField(first);

                dfr = getFieldResultByLocalNameOfSObject(objType,localFieldName);

                if(!dfr.getReferenceTo().isEmpty()){
                    objtype = dfr.getReferenceTo()[0];

                }

                qualifiedParentFields.add( reverseParentField(dfr.getName()) );

                getQualifiedParentFieldNames(objtype,remained);

            }else{
                dfr = getFieldResultByLocalNameOfSObject(objType,fieldNames);
                qualifiedParentFields.add( dfr.getName() );
            }
            return String.join(qualifiedParentFields,'.');
        
        }catch(Exception ex){
            throw new SQueryException('Error occured on getQualifiedParentFieldNames method : ' + ex.getMessage());
        }
    }

    private static DescribeFieldResult getFieldResultByLocalNameOfSObject(SObjectType objType,String fieldName){
        try{
            Map<String,Schema.SObjectField> fields = objType.getDescribe().fields.getMap();
            DescribeFieldResult qualifiedField;
            for(String field: fields.keySet()){
               DescribeFieldResult dfr =  fields.get(field).getDescribe();
               if( dfr.getLocalName().equalsIgnoreCase(fieldName) ){
                    qualifiedField = dfr;
                    break;
               }
            }
            return qualifiedField;
        }catch(Exception ex){
            throw new SQueryException(ex.getMessage());
        }
    }

    //This is a static helper method that returns the qualified parent field name
    public static String getQualifiedName(SObjectType objType,String fieldName){
        Squery sq = new SQuery(objType);
        return sq.getQualifiedParentFieldNames(objType, fieldName);
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
                getQualifiedFieldName(fieldName.trim()), 
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
        if(this.enforceFLS && !this.sobjectResult.isAccessible()){
            throw new SObjectException('User has not permission to access that '+ this.sobjectResult.getName() + ' object');
        }
        try{
           return new List<SObject>( Database.query(this.toSoql()) );
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
            obj = namespace + '__' + obj;
            
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

    public String toSoql(){

        String formatString = 'SELECT {0} FROM {1}';
        if(this.objectType ==null ){
            throw new SQueryException('Seems that any sObject type was not specified.Sobject type is required.');
        }
        if(this.fields.isEmpty()){
           this.fields = new Set<String>{'Id'};
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
               //this.fields.add(temp);
               this.subQueryAsFields.add(temp);
           }
        }
        List<String> mergeAllFields = new List<String>(this.fields);
        mergeAllFields.addAll(this.parentFields);
        mergeAllFields.addAll(this.subQueryAsFields);    

        List<String> args = new String[]{
           String.join(mergeAllFields,','),
           this.objectName
        };
           
        soql = String.format(formatString,args);

        if(!this.conditions.isEmpty()){
            soql += ' WHERE ';
            List<String> whereConditions = new List<String>();
            for(Condition c: this.conditions){
                whereConditions.add(c.toSoql());
            }
            soql += String.join(whereConditions, ' AND ');
        }

        if(!this.conditions.isEmpty() && this.additionalWhereClause!=null){
            soql += ' ' + this.additionalWhereClause;
        }

        if(this.conditions.isEmpty() && this.additionalWhereClause!=null){
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

    public SQuery setSharingRules(){
        if(! objectType.getDescribe().isAccessible()){
            throw new SQueryException('Permission Denied: cannot read ' + objectType.getDescribe().getName() + ' object');
        }
        Set<String> notAcccessibleFields = new Set<String>();
        for(String fn : this.fields){
            String fnLower = fn.toLowerCase();
            if(sobjectFields.containsKey(fnLower)){
                Schema.DescribeFieldResult fresult = sobjectFields.get(fnLower).getDescribe();
                if(!fresult.isAccessible()){
                    notAcccessibleFields.add(fresult.getName());
                }
            }
        }
        if(!notAcccessibleFields.isEmpty()){
            throw new SQueryException('Permission Denied: cannot read ' + notAcccessibleFields + ' field(s)');
        }
        return this;
    }

    public String getQualifiedSObjectName(){
        return this.objectName;
    }

    public List<String> getQualifiedFieldNames(){
        List<String> allFields = new List<String>(this.fields);
        allFields.addAll(this.parentFields);
        return allFields;
    }

    private String getReferenceFieldName(String fieldRel){
        if(fieldRel.endsWithIgnoreCase('__r')){
           return fieldRel.removeEnd('__r') + '__c';    
        }else{
            return fieldRel;
        }
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