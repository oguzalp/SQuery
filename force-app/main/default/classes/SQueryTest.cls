@isTest
public class SQueryTest
{   
    @TestSetup
    static void createTestData(){
        Account ac = new Account(
            Name = 'Acme Co',
            AccountNumber = 'AC-1234',
            AccountSource = 'Web',
            AnnualRevenue = 1500000,
            NumberOfEmployees = 150, 
            Rating = 'Hot',
            Type = 'Customer'
        );
        insert(ac);

        Contact c = new Contact(
            FirstName = 'TestFN',
            Lastname = 'TestLN',
            Phone = '9555 1213312',
            Birthdate = Date.today().addYears(-35),
            AccountId = ac.Id
        );

        insert(c);
    }

    @isTest
    static void query_all_fields(){

        SQuery sq = new SQuery('Contact')
            .selectAll();

        List<Contact> cts = sq.runQuery();

        System.assertEquals(1, cts.size());

        Set<String> cFields =  Contact.getSobjectType().getDescribe().fields.getMap().keyset();
        String expectedQuery = 'SELECT ' + String.join(new List<String>(cFields), ',') + ' FROM Contact';
        
        System.assert(expectedQuery.equalsIgnoreCase(sq.toSoql()));

    }

    @isTest
    static void test_parent_fields_with_enforce_fls(){
        try{
            String test_query = new SQuery(Contact.SObjectType)
            .enforceFLS()
            .addFields('Id,FirstName,LastName')
            .addParentField('Account.Name')
            .addParentField('Account.AccountSource')
            .toSoql();

            System.assertEquals('SELECT Id,FirstName,LastName,Account.Name,Account.AccountSource FROM Contact',test_query);

        }catch(SQuery.SQueryException ex){
            System.assert(ex.getMessage().contains('User has not permission'));
        }
        
    }

    @isTest
    static void test_limit_and_offset_query()
    {   
        String query = 
            new SQuery(Account.sObjectType)
                .addFields('Id,AccountSource,AccountNumber')
                .setLimit(50)
                .offset(10)
                .toSoql();

        System.assertEquals('SELECT Id,AccountSource,AccountNumber FROM Account LIMIT 50 OFFSET 10', query);
    }
    
    @isTest
    static void test_add_condition()
    {
        SQuery query = new SQuery(Account.SObjectType)
                .addFields('Id,Name,AccountNumber')
                .addCondition(new Field('AccountNumber').equals('AC-1234'));
        
        List<Account> acs = query.runQuery();

        System.assertEquals(1, acs.size());
        System.assertEquals('SELECT Id,Name,AccountNumber FROM Account WHERE AccountNumber = \'AC-1234\'',query.toSoql());
                
    }

    @isTest
    static void test_getRecordById()
    {
        Account ac = [Select Id From Account Limit 1];

        String query = new SQuery(Account.SObjectType)
                .addFields('Id,Name,AccountNumber')
                .getRecordById(ac.Id)
                .toSoql();
        
        System.assertEquals('SELECT Id,Name,AccountNumber FROM Account WHERE Id = \'' + ac.Id + '\'' ,query);
                
    }

     @isTest
    static void test_getRecordsByIdList()
    {
        Account ac = [Select Id From Account Limit 1];

        String query = new SQuery(Account.SObjectType)
                .addFields('Id,Name,AccountNumber')
                .getRecordById(new List<Id>{ac.Id})
                .toSoql();
        
        System.assertEquals('SELECT Id,Name,AccountNumber FROM Account WHERE Id IN (\'' + ac.Id + '\')' ,query);
                
    }
    
}