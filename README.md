# SQuery Plugin

> SQuery is an apex plugin that helps you to create dynamic soql queries with a structural and flexible way. It also allows you to enforce field/object level securities while you are running your queries besides that it adds the package prefixes to custom objects and its custom fields that you use in your queries.

# Installation
  
#### Installation to your scratch org.
  
```console
# Set the defaultdevhubusername
sfdx force:config:set defaultdevhubusername=<yourdevhubusername>
  
# Create a new scratch org if you don't already have it 
sfdx force:org:create -f config/project-scratch-def.json -a squery-org
  
# push the source code to your scractch org
sfdx force:source:push -u test-plcehsuzpvsp@example.com
  
# open your org.
sfdx force:org:open -u test-plcehsuzpvsp@example.com
```
  
#### Installation to your non-scratch org(s).
  
```console
# Login your developer or sandbox org with the following sfdx command
sfdx force:auth:web:login --setalias my-dev-org
  
# Deploy the source code to your org
sfdx force:source:deploy -p force-app -u my-dev-org 
```
  
# Usage

#### Select query fields

You can select query fields by using addFields methods. you can either give comma separated fields or a List of fields as an argument.
If you do not add any fields to your query, Squery adds the Id field of that given sobject as a default.

```java
List<Account> accounts= new SQuery('Account')
    .addFields('Id,Name,AccountSource')
    .runQuery();
//or you can send a list of fields to addFields method
//also Squery can be initialized by an SobjectType
List<Account> accounts= new SQuery(Account.SObjecType)
    .addFields(new List<String>{'Id','Name,AccountSource'})
    .runQuery();

//this is equivalent to List<Account> accounts = [SELECT Id,Name,AccountSource From Account];
```

#### Enforce Object/Field Level Security
The following query will enforce field level securities. If the running user has no permission to read one of the fields in the query, Squery will throw a permission error.

```java
List<Account> accounts= new SQuery('Account')
    .enforceFLS()
    .addFields('Id,Name,AccountSource,AnnualRevenue')
    .runQuery();
```

#### Select all fields

This will select all fields that belongs to specified object type.

```java
List<Account> accounts= new SQuery(Account.SObjectType)
    .enforceFLS()
    .selectAll()
    .runQuery();
```

#### Select fields by given Field Set

The following code will query the fields that are specified in `field_set_name` fieldset that is created for Account object.

```java
List<Account> accounts = new SQuery(Account.SObjectType)
  .setFieldSet('field_set_name')
  .runQuery();
```

#### Select Parent Fields

In order for selecting parent fields, you must leverage the addParentField() or addParentFields() method.

```java
String query = new SQuery('Case')
  .addFields('Id,Subject,Type,Status')
  .addParentFields('Account.Name','Owner.Email')
  .toSoql(); //toSoql method return the generated query as string 

System.assertEquals(query,'SELECT Id,Subject,Type,Status,Account.Name,Owner.Email FROM Case');
```

#### Set LIMIT 

```java
String query = new SQuery('Case')
  .addFields('Id,Subject,Type,Status')
  .setLimit(100)
  .toSoql(); //toSoql method return the generated query as string 

System.assertEquals(query,'SELECT Id,Subject,Type,Status FROM Case LIMIT 100');
```

#### Offset usage

```java
String query = new SQuery('Case')
  .addFields('Id,Subject,Type,Status')
  .setLimit(100)
  .offSet(10)
  .toSoql(); //toSoql method return the generated query as string 

System.assertEquals(query,'SELECT Id,Subject,Type,Status FROM Case LIMIT 100 OFFSET 10');
```

#### Add Order BY statement
orderBy method accepts two arguments, first param is field API name <String>, second param is SortDirection enum type,
available enum types are;
SortDirection.ASCENT,SortDirection.DESCENT,SortDirection.ASC_NULL_LAST,SortDirection.DESC_NULL_LAST

```java
List<Account> = new SQuery('Account')
  .addFields('Id,Name,CreatedDate')
  .orderBy('CreatedDate',SortDirection.ASCENT)
  .orderBy('Name',SortDirection.DESCENT)
  .runQuery();

// It is equivalent to
// List<Account> accounts = 
  // Database.query('SELECT Id,Name,CreatedDate FROM Account ORDER BY CreatedDate ASC,Name DESC');
```

#### Get Record By Id

The following code will return the account by given Id. 

```java
String accountId = '0010Y00000rFprSQAS';
String query = new SQuery('Account')
    .addFields('Id,Name,CreatedDate')
    .getRecordById(accountId)
    .toSoql();
 
System.assertEquals('SELECT Id,Name,CreatedDate FROM Account WHERE Id ='\'0015C00000M7IEwQAN'\'',query);
```
It is possible to fetch all account records by the given list of Id 

```java
List<Id> idList = new List<String>{'0010Y00000rFprSQAS','0010Y00000DWdKIQA1'};
String query = new SQuery('Account')
    .addFields('Id,Name,CreatedDate')
    .getRecordById(idList)
    .toSoql();

// the query is equivalent to
// SELECT Id,Name,CreatedDate FROM Account WHERE Id IN ('0015C00000M7IEwQAN','0010Y00000DWdKIQA1')
```