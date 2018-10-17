{
  title: "Ultipro",

  connection: {
    fields: [
      {
        name: "username",
        label: "Username",
        optional: false,
        hint: "Your Ultipro username"
      },
      {
        name: "password",
        label: "Password",
        control_type: "password",
        optional: false,
        hint: "Your Ultipro password"
      },
      {
        name: "api-key",
        label: "Ultipro API key",
        optional: false,
        hint: "Your Ultipro API key" #add link for hint
      },
    ],

    base_uri: ->(_connection) { "https://service2.ultipro.com" },

    authorization: {
      type: 'basic_auth',

      credentials: lambda do |connection|
        user(connection['username'])
        password(connection['password'])
      end,

      apply: lambda do |_connection, access_token|
        headers("US-Customer-Api-Key" => "#{api-key}")
      end
  },

  object_definitions: {
    pto_plan: {
      fields: lambda do |_connection, _config_fields|
        [
          { name: "employeeId", type: "string", label: "Employee ID" },
          { name: "companyId", type: "string", label: "Company ID" },
          { name: "ptoPlan", type: "string", label: "PTO plan" },
          { name: "earned", type: "number", control_type: "number", label: "Earned" },
          { name: "taken", type: "number", control_type: "number", label: "Taken" },
          { name: "pendingBalance", type: "number", control_type: "number", label: "Pending Balance" },
          { name: "earnedThroughDate", type: "string", label: "Earned through date" },
          { name: "reset", type: "string", label: "PTO reset date" },
          { name: "pendingMoveDate ", type: "string", label: "Pending move date" },
        ]
      end
    },

    employee: {
      fields: lambda do |_connection, _config_fields|
        [
          { name: "firstName", type: "string", label: "First name" },
          { name: "lastName", type: "string", label: "Last name" },
          { name: "preferredName", type: "string", label: "Preferred name" },
          { name: "emailAddress", type: "string", label: "Email address" },
          { name: "countryCode", type: "string", label: "Country code" },
          { name: "languageCode", type: "string", label: "Language code" },
          { name: "employeeNumber", type: "number", label: "Employee number" },
          { name: "employeeId", type: "string", label: "Employee ID" },
          { name: "personId ", type: "string", label: "Person ID" },
          { name: "userIntegrationKey", type: "string", label: "User integration key" },
          { name: "companyName", type: "string", label: "Company name" },
          { name: "companyId", type: "string", label: "Company ID" },
          { name: "supervisorId", type: "string", label: "Surpervisor ID" },
          { name: "salaryOrHourly", type: "string", label: "Hourly Salary" },
          { name: "fullTimeOrPartTime", type: "string", label: "Full or Part Time ID" },
          { name: "isActive", type: "boolean", label: "Is active" },
          { name: "workLocation", type: "string", label: "Work location" },
          { name: "jobCode", type: "string", label: "Job code" },
          { name: "projectCode", type: "string", label: "Project code" },
          { name: "orgLevel1Code", type: "string", label: "Orginizational Level 1" },
          { name: "orgLevel2Code", type: "string", label: "Orginizational Level 2" },
          { name: "orgLevel3Code", type: "string", label: "Orginizational Level 3" },
          { name: "orgLevel4Code", type: "string", label: "Orginizational Level 4" },
          { name: "middleName", type: "string", label: "Middle name" },
          { name: "workPhone", type: "string", label: "Work phone" },
          { name: "homePhone", type: "string", label: "Home phone" },
          { name: "employeeAddress1", type: "string", label: "Employee address 1" },
          { name: "employeeAddress2", type: "string", label: "Employee address 2" },
          { name: "city", type: "string", label: "City" },
          { name: "state", type: "string", label: "State" },
          { name: "zipCode", type: "string", label: "Zip code" },
          { name: "terminationDate", type: "string", label: "Termination date" },
          { name: "hireDate", type: "string", label: "Hire date" },
          { name: "supervisorName", type: "string", label: "Supervisor name" },
          { name: "prefix", type: "string", label: "Name prefix" },
          { name: "suffix", type: "string", label: "Name suffix" },
          { name: "alternateEmailAddress", type: "string", label: "Alternative email address" },
          { name: "gender", type: "string", label: "Gender" },
        ]
      end
    },

  test: lambda do |_connection|
      get("/personnel/v1/employee-changes")
    end,

  actions: {
    get_pto_plan_by_id: {
      description: "Get <span class='provider'>PTO plans by ID</span> " \
        "in <span class='provider'>Ultipro</span>",

      input_fields: lambda do |object_definitions|
        object_definitions["pto_plan"].
          only("companyId", "employeeId").
          required("companyId", "employeeId")
      end,

      execute: lambda do |_connection, input|
        pto = get("/personnel/v1/companies/#{companyId}/employees/#{employeeId}/pto-plans")["pto-plans"]

        { "pto-plans": pto }
      end,

      output_fields: lambda do |object_definitions|
        [
          {
            name: "pto-plans",
            type: :array,
            of: :object,
            properties: object_definitions["pto_plan"]
          }
        ]
      end,

      sample_output: lambda do |_connection, input|
        {
          "pto-plans": get("/personnel/v1/companies/#{companyId}/employees/#{employeeId}/pto-plans").
                         params(page: 1, per_page: 1)["pto-plans"]
        }
      end
    }
  }

  triggers: {
    new_employee: {
      input_fields: lambda do
        [
          {
            name: 'since',
            type: :timestamp,
            optional: false
          }
        ]
      end,

      poll: lambda do |connection, input, last_updated_since|
        page_size = 100
        updated_since = (last_updated_since || input['since']).to_time.utc.iso8601

        employee = get("/personnel/v1/employee-changes").
                  params(per_page: page_size,
                         startDate: updated_since)

        next_updated_since = employee.last['hireDate'] unless employee.blank?

        {
          events: employee,
          next_poll: next_updated_since,
          can_poll_more: employee.length >= page_size
        }
      end,

      dedup: lambda do |ticket|
        employee['employeeId']
      end,

      output_fields: lambda do |object_definitions|
        [
          {
            name: "EmployeeChangesResponse",
            type: :array,
            of: :object,
            properties: object_definitions["employee"]
          }
        ]
      end,

      sample_output: lambda do |_connection, input|
        {
          "EmployeeChangesResponse": get("/personnel/v1/employee-changes").
                                       params(page: 1, per_page: 1)
                                       ["EmployeeChangesResponse"]
        }
      end
    }

  },

}
