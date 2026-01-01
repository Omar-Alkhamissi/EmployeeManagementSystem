use master;
GO
Alter database Project3  set single_user with rollback immediate;
GO
DROP Database Project3;
GO 

CREATE DATABASE Project3;
GO

USE Project3;
GO

CREATE TABLE dbo.Departments (
    DepartmentID       INT IDENTITY PRIMARY KEY,
    DepartmentName NVARCHAR(50) NOT NULL,
    DepartmentDesc  NVARCHAR(100) CONSTRAINT DF_DFDeptDesc DEFAULT 'Actual Dept. Desc to be determined'
);

CREATE TABLE dbo.Employees (
    EmployeeID               INT IDENTITY PRIMARY KEY,
    DepartmentID            INT CONSTRAINT FK_Employee_Department FOREIGN KEY REFERENCES dbo.Departments ( DepartmentID ),
    ManagerEmployeeID INT CONSTRAINT FK_Employee_Manager FOREIGN KEY REFERENCES dbo.Employees ( EmployeeID ),
    FirstName                  NVARCHAR(50),
    LastName                  NVARCHAR(50),
    Salary                        MONEY CONSTRAINT CK_EmployeeSalary CHECK ( Salary >= 0 ),
    CommissionBonus    MONEY CONSTRAINT CK_EmployeeCommission CHECK ( CommissionBonus >= 0 ),
    FileFolder                  NVARCHAR(256) CONSTRAINT DF_FileFolder DEFAULT 'ToBeCreated'
);

GO
INSERT INTO dbo.Departments ( DepartmentName, DepartmentDesc )
VALUES ( 'Management', 'Executive Management' ),
       ( 'HR', 'Human Resources' ),
       ( 'Database', 'Database Administration'),
       ( 'Support', 'Product Support' ),
       ( 'Software', 'Software Sales' ),
       ( 'Marketing', 'Digital Marketing' );
GO

SET IDENTITY_INSERT dbo.Employees ON;
GO

INSERT INTO dbo.Employees ( EmployeeID, DepartmentID, ManagerEmployeeID, FirstName, LastName, Salary, CommissionBonus, FileFolder )
VALUES ( 1, 4, NULL, 'Sarah', 'Campbell', 78000, NULL, 'SarahCampbell' ),
       ( 2, 3, 1, 'James', 'Donoghue',     68000 , NULL, 'JamesDonoghue'),
       ( 3, 1, 1, 'Hank', 'Brady',        76000 , NULL, 'HankBrady'),
       ( 4, 2, 1, 'Samantha', 'Jonus',    72000, NULL , 'SamanthaJonus'),
       ( 5, 3, 4, 'Fred', 'Judd',         44000, 5000, 'FredJudd'),
       ( 6, 3, NULL, 'Hanah', 'Grant',   65000, 4000 ,  'HanahGrant'),
       ( 7, 3, 4, 'Dhruv', 'Patel',       66000, 2000 ,  'DhruvPatel'),
       ( 8, 4, 3, 'Dash', 'Mansfeld',     54000, 5000 ,  'DashMansfeld');
GO

SET IDENTITY_INSERT dbo.Employees OFF;
GO

CREATE FUNCTION dbo.GetEmployeeID (
    -- Parameter datatype and scale match their targets
    @FirstName NVARCHAR(50),
    @LastName  NVARCHAR(50) )
RETURNS INT
AS
BEGIN;


    DECLARE @ID INT;

    SELECT @ID = EmployeeID
    FROM dbo.Employees
    WHERE FirstName = @FirstName
          AND LastName = @LastName;

    -- Note that it is not necessary to initialize @ID or test for NULL, 
    -- NULL is the default, so if it is not overwritten by the select statement
    -- above, NULL will be returned.
    RETURN @ID;
END;
GO

-- DROP PROCEDURE InsertDepartment;

CREATE OR ALTER PROCEDURE dbo.InsertDepartment
    @DepartmentName NVARCHAR(50),
    @DepartmentDesc NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    IF @DepartmentDesc IS NULL
    BEGIN
        -- Insert only DepartmentName, so DepartmentDesc uses its default value
        INSERT INTO dbo.Departments (DepartmentName)
        VALUES (@DepartmentName);
    END
    ELSE
    BEGIN
        -- Insert both DepartmentName and DepartmentDesc if a value is provided
        INSERT INTO dbo.Departments (DepartmentName, DepartmentDesc)
        VALUES (@DepartmentName, @DepartmentDesc);
    END

    SELECT SCOPE_IDENTITY() AS NewDepartmentID;
END;
GO

EXEC dbo.InsertDepartment 'QA', 'Quality Assurance';
EXEC dbo.InsertDepartment 'SysDev', 'Systems Development';
EXEC dbo.InsertDepartment 'Infrastructure', 'Deployment and Production Support';
EXEC dbo.InsertDepartment 'DesignEngineering', 'Project Initiation/Design/Engineering';


/* Confirm the records were successfully added by selecting all departments */
SELECT * FROM dbo.Departments;
GO

CREATE OR ALTER FUNCTION dbo.GetDepartmentID
    (@DepartmentName NVARCHAR(50))
RETURNS INT
AS
BEGIN
    DECLARE @DeptID INT;

    -- Retrieve the DepartmentID for the given DepartmentName
    SELECT @DeptID = DepartmentID
    FROM dbo.Departments
    WHERE DepartmentName = @DepartmentName;

    -- Return the DepartmentID, or NULL if not found
    RETURN @DeptID;
END;
GO


CREATE OR ALTER PROCEDURE dbo.InsertEmployee
    @DepartmentName NVARCHAR(50),
    @EmployeeFirstName NVARCHAR(50),
    @EmployeeLastName NVARCHAR(50),
    @Salary MONEY = 46000,
    @FileFolder NVARCHAR(256),
    @ManagerFirstName NVARCHAR(50),
    @ManagerLastName NVARCHAR(50),
    @CommissionBonus MONEY = 5000
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    DECLARE @DeptID INT;
    DECLARE @ManagerID INT;

    -- Get or create DepartmentID
    SET @DeptID = dbo.GetDepartmentID(@DepartmentName);
    IF @DeptID IS NULL
    BEGIN
        -- Insert new department and get its ID
        EXEC dbo.InsertDepartment @DepartmentName;
        SET @DeptID = dbo.GetDepartmentID(@DepartmentName);
    END

    -- Get or create ManagerID
    SET @ManagerID = dbo.GetEmployeeID(@ManagerFirstName, @ManagerLastName);
    IF @ManagerID IS NULL
    BEGIN
        -- Insert new manager with increased salary
        INSERT INTO dbo.Employees (DepartmentID, FirstName, LastName, Salary, FileFolder)
        VALUES (@DeptID, @ManagerFirstName, @ManagerLastName, @Salary + 12000, @ManagerFirstName + @ManagerLastName);
        
        -- Retrieve the new ManagerID
        SET @ManagerID = dbo.GetEmployeeID(@ManagerFirstName, @ManagerLastName);
    END

    -- Insert the new employee record
    BEGIN TRY
        INSERT INTO dbo.Employees (DepartmentID, ManagerEmployeeID, FirstName, LastName, Salary, CommissionBonus, FileFolder)
        VALUES (@DeptID, @ManagerID, @EmployeeFirstName, @EmployeeLastName, @Salary, @CommissionBonus, @FileFolder);

        -- Commit the transaction if the employee insertion succeeds
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Rollback the transaction if there is an error
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

EXEC dbo.InsertEmployee 
    @DepartmentName = 'Deployment', 
    @EmployeeFirstName = 'Wherewolf', 
    @EmployeeLastName = 'Waldo', 
    @FileFolder = 'WherewolfWaldo', 
    @ManagerFirstName = 'Carter', 
    @ManagerLastName = 'Von Bommel';

EXEC dbo.InsertEmployee 
    @DepartmentName = 'Database', 
    @EmployeeFirstName = 'Adib', 
    @EmployeeLastName = 'Tolo', 
    @Salary = 43000, 
    @FileFolder = 'Adib Tolo', 
    @ManagerFirstName = 'Omar', 
    @ManagerLastName = 'Alkhamissi', 
    @CommissionBonus = 4000;


SELECT * FROM dbo.Employees;
SELECT * FROM dbo.Departments;
GO

CREATE OR ALTER FUNCTION dbo.GetEmployeesByCommission (@MinCommission MONEY)
RETURNS TABLE
AS
RETURN
(
    -- Only select records if the provided commission is >= 0
    SELECT 
        d.DepartmentName,
        d.DepartmentDesc,
        e.FirstName,
        e.LastName,
        e.Salary,
        e.CommissionBonus,
        e.FileFolder
    FROM 
        dbo.Employees AS e
    INNER JOIN 
        dbo.Departments AS d ON e.DepartmentID = d.DepartmentID
    WHERE 
        e.CommissionBonus > @MinCommission
        AND @MinCommission >= 0
);
GO

-- Test with a commission value of 5000
SELECT * FROM dbo.GetEmployeesByCommission(5000);

-- Test with a commission value of 4000
SELECT * FROM dbo.GetEmployeesByCommission(4000);

SELECT 
    d.DepartmentName,
    e.FirstName,
    e.LastName,
    e.Salary,
    e.CommissionBonus,
    (e.Salary + COALESCE(e.CommissionBonus, 0)) AS Compensation,
    RANK() OVER(PARTITION BY d.DepartmentName ORDER BY (e.Salary + COALESCE(e.CommissionBonus, 0)) DESC) AS DepartmentRank,
    LAG(e.FirstName) OVER(PARTITION BY d.DepartmentName ORDER BY (e.Salary + COALESCE(e.CommissionBonus, 0)) DESC) AS PrevEmployeeFirstName,
    LAG(e.LastName) OVER(PARTITION BY d.DepartmentName ORDER BY (e.Salary + COALESCE(e.CommissionBonus, 0)) DESC) AS PrevEmployeeLastName,
    LAG(e.Salary + COALESCE(e.CommissionBonus, 0)) OVER(PARTITION BY d.DepartmentName ORDER BY (e.Salary + COALESCE(e.CommissionBonus, 0)) DESC) AS PrevEmployeeCompensation,
    AVG(e.Salary + COALESCE(e.CommissionBonus, 0)) OVER(PARTITION BY d.DepartmentName) AS AvgDepartmentCompensation
FROM 
    dbo.Employees AS e
INNER JOIN 
    dbo.Departments AS d ON e.DepartmentID = d.DepartmentID
ORDER BY 
    d.DepartmentName, DepartmentRank;
GO

WITH EmployeeHierarchy AS (
    -- Anchor Member: Start with employees who have no manager (top-level managers)
    SELECT 
        e.EmployeeID,
        e.LastName AS EmployeeLastName,
        e.FirstName AS EmployeeFirstName,
        e.DepartmentID,
        e.FileFolder,
        CAST(NULL AS NVARCHAR(50)) AS ManagerLastName,
        CAST(NULL AS NVARCHAR(50)) AS ManagerFirstName,
        CAST(e.FileFolder AS NVARCHAR(MAX)) AS FilePath
    FROM 
        dbo.Employees AS e
    WHERE 
        e.ManagerEmployeeID IS NULL

    UNION ALL

    -- Recursive Member: Find employees who report to the employees in the previous level
    SELECT 
        e.EmployeeID,
        e.LastName,
        e.FirstName,
        e.DepartmentID,
        e.FileFolder,
        m.EmployeeLastName AS ManagerLastName,
        m.EmployeeFirstName AS ManagerFirstName,
        CAST(m.FilePath + '\' + e.FileFolder AS NVARCHAR(MAX)) AS FilePath
    FROM 
        dbo.Employees AS e
    INNER JOIN 
        EmployeeHierarchy AS m ON e.ManagerEmployeeID = m.EmployeeID
)

-- Final Select to get desired columns
SELECT 
    EmployeeLastName,
    EmployeeFirstName,
    DepartmentID,
    FileFolder,
    ManagerLastName,
    ManagerFirstName,
    FilePath
FROM 
    EmployeeHierarchy
ORDER BY 
    FilePath;
GO