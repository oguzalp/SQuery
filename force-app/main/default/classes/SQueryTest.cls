@isTest
public class SQueryTest
{   

    @isTest
    static void query_all_fields(){

        List<Contact> contacts = (List<Contact>)(new SQuery('Contact')
            .selectAll()
            .runQuery());
    }

    @isTest
    static void test_parent_fields(){
        String test_query = new SQuery(Contact.SObjectType)
            .enforceFLS()
            .addFields('Id,FirstName,LastName')
            .addParentField('Account.Name')
            .addParentField('Account.AccountSource')
            .toSoql();

        System.assertEquals('SELECT Id,FirstName,LastName,Account.Name,Account.AccountSource FROM Contact');
    }

    @isTest
    static void test_condition()
    {   
        String qry = 
        new SQuery(Account.sObjectType)
            .addFields('Id,AccountSource,AccountNumber,RecordTypeId')
            .setLimit(50)
            .offset(10)
            .toSoql();

        System.assertEquals('SELECT Id,AccountSource,AccountNumber,RecordTypeId FROM Account LIMIT 50 OFFSET 10', qry);
    }
    
    @isTest
    static void test_complex_query()
    {
        
    }
    
}