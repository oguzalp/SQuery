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
            .addParentFields('Account.Name,Account.AccountSource')
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
				//Testing get getQualifiedSObjectName
				System.assertEquals('Account',query.getQualifiedSObjectName());
				//Testing get getQualifiedFieldNames
				List<String> qualified_fields = query.getQualifiedFieldNames();
        System.assertEquals(qualified_fields.get(0),'Id');
				System.assertEquals(qualified_fields.get(1),'Name');
				System.assertEquals(qualified_fields.get(2),'AccountNumber');      
    }

		@isTest
    static void test_additional_condition()
    {
        String query = new SQuery(Account.SObjectType)
                .addFields('Id,Name,AccountNumber')
                .addCondition(new Field('AccountNumber').equals('AC-1234'))
								//condition can be a totally where clause string
								.addCondition('AND AccountSource = \'Web\'')
								.toSoql();

				System.assertEquals(query,
					'SELECT Id,Name,AccountNumber FROM Account WHERE AccountNumber = \'AC-1234\' AND AccountSource = \'Web\'');
           
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

    @isTest
    static void test_group_condition()
    {
        List<String> fieldList = new List<String>{'Id','Name','AccountSource'};
        String query = new SQuery('Account')
					.addFields(fieldList)
					.addCondition(
            new andCondition()
              .add(new Field('AccountSource').equals('Web'))
              .add( 
                new orCondition()
                  .add(new Field('Rating').notEquals('Hot'))
                  .add(new Field('AnnualRevenue').greaterThan(1500000))
                )
            ).toSoql();
        
        String expectedQuery = 'SELECT Id,Name,AccountSource FROM Account WHERE (AccountSource = \'Web\' AND (Rating != \'Hot\' OR AnnualRevenue > 1500000))';
        System.assertEquals(expectedQuery ,query);                
    }

    @isTest
    static void test_sub_query()
    {
      String query =
        new SQuery('Account')
            .addFields('Id,Name,AccountSource')
            .addSubQuery(
            	new SQuery(Opportunity.SObjectType,'Opportunities')
                .addFields('Id,Amount,StageName')
                .addCondition(new Field('Amount').greaterThan(50000))
      	).toSoql();
  
  			System.assertEquals(query,
    			'SELECT Id,Name,AccountSource,(SELECT Id,Amount,StageName FROM Opportunities WHERE Amount > 50000) FROM Account'
				);                  
  	}

		@isTest
    static void test_order_by()
    {
			String query = new SQuery('Account')
				.addFields('Id,Name,CreatedDate')
				.orderBy('CreatedDate',SortDirection.ASCENT)
				.orderBy('Name',SortDirection.DESCENT)
				.toSoql();
			
			System.assertEquals('SELECT Id,Name,CreatedDate FROM Account ORDER BY CreatedDate ASC,Name DESC',query);
		}

		@isTest
    static void test_for_view()
    {
			String query = new SQuery(Case.getSObjectType())
				.addFields('Id,CaseNumber')
				.addParentField('Account.Name')
				.forView()
				.toSoql();
			
			System.assertEquals('SELECT Id,CaseNumber,Account.Name FROM Case FOR VIEW',query);
		}

		@isTest
    static void test_for_update()
    {
			String query = new SQuery(Account.getSObjectType())
				.addFields('Id,Name')
				.forUpdate()
				.toSoql();
			
			System.assertEquals('SELECT Id,Name FROM Account FOR UPDATE',query);
		}

		@isTest
    static void test_for_reference()
    {
			String query = new SQuery(Contact.getSObjectType())
				.addFields('Id,FirstName,LastName')
				.forReference()
				.toSoql();
			
			System.assertEquals('SELECT Id,FirstName,LastName FROM Contact FOR REFERENCE',query);
		}

		@isTest
    static void test_select_fields_in_fieldset()
    {
			try{
				List<Contact> contacts =
					new SQuery(Contact.sObjectType)
						.setFieldSet('test_field_set_name')
						.runQuery();

			}catch(Squery.SQueryException ex){
				System.assertEquals('the given field set can not be found.',ex.getMessage());
			}
		}

		@isTest
    static void test_all_field_conditions()
    {

			Account ac = [Select Id From Account Limit 1];

			System.assertEquals('Name = \'John\'',new Field('Name').equals('John').toSoql());
			
			System.assertEquals('Name != \'John\'',new Field('Name').notEquals('John').toSoql());
			 
			System.assertEquals('Amount < 5000',new Field('Amount').lessThan(5000).toSoql()); 
			
			System.assertEquals('CreatedDate < YESTERDAY',
				new Field('CreatedDate').lessThan(DateLiteral.YESTERDAY).toSoql()); 		
			
			String today_date = String.valueOf(Date.today());
			System.assertEquals('CreatedDate < ' + today_date,
				new Field('CreatedDate').lessThan(Date.today()).toSoql()); 		
			 
			System.assertEquals('AnnualRevenue <= 1500000',
				new Field(Account.AnnualRevenue).lessThanOrEqual(1500000).toSoql());

			System.assertEquals('AnnualRevenue > 1500000',
				new Field(Account.AnnualRevenue).greaterThan(1500000).toSoql());
			
			System.assertEquals('AnnualRevenue >= 1500000',
				new Field(Account.AnnualRevenue).greaterThanOrEqual(1500000).toSoql());
			
			System.assertEquals('FirstName LIKE \'%John%\'',
				new Field(Contact.FirstName).isLike('%John%').toSoql());
			
			System.assertEquals('FirstName LIKE \'John%\'',
				new Field(Contact.FirstName).startWith('John').toSoql());
			
			System.assertEquals('FirstName LIKE \'%John\'',
				new Field(Contact.FirstName).endWith('John').toSoql());
			
			System.assertEquals('FirstName LIKE \'%John%\'',
				new Field(Contact.FirstName).contains('John').toSoql());
			
			System.assertEquals('Custom_MultiSelectPicklist_Field__c INCLUDES (\'itemA;itemB\')',
				new Field('Custom_MultiSelectPicklist_Field__c').includes('itemA;itemB').toSoql());
			
			System.assertEquals('Custom_MultiSelectPicklist_Field__c EXCLUDES (\'itemA;itemB\')',
				new Field('Custom_MultiSelectPicklist_Field__c').excludes('itemA;itemB').toSoql());
	
			SQuery query = new Squery('Account')
				.addFields('Id,Name')
				.addCondition(new Field('ID').isIN(new List<Id>{ac.Id}));

			String expectedQuery = 'SELECT Id,Name FROM Account WHERE ID IN (\'' +ac.Id + '\')';
			System.assertEquals(query.toSoql(),expectedQuery);
			System.assertEquals(query.runQuery().get(0).Id, ac.Id);
			
			System.assertEquals('Id NOT IN (\'0015C00000M7IMRQA3\')',
				new Field(Account.Id).notIN(new List<Id>{ '0015C00000M7IMRQA3'}).toSoql() );

			System.assertEquals('FirstName = NULL',
				new Field(Contact.FirstName).isNull().toSoql());
			
			System.assertEquals('FirstName != NULL',
				new Field(Contact.FirstName).isNotNull().toSoql());
		
		}	
}