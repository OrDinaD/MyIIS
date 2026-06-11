import XCTest
@testable import MyIIS

@MainActor
final class LoginViewModelTests: XCTestCase {
    
    var viewModel: LoginViewModel!
    var authService: AuthenticationService!
    
    override func setUp() {
        super.setUp()
        // Initialize with default or mocked dependencies
        authService = AuthenticationService(allowSessionRestore: false)
        viewModel = LoginViewModel(authService: authService)
    }
    
    override func tearDown() {
        viewModel = nil
        authService = nil
        super.tearDown()
    }
    
    func testClearForm() {
        // Arrange
        viewModel.username = "testUser"
        viewModel.password = "password123"
        
        // Act
        viewModel.clearForm()
        
        // Assert
        XCTAssertTrue(viewModel.username.isEmpty, "Username should be empty after clearForm")
        XCTAssertTrue(viewModel.password.isEmpty, "Password should be empty after clearForm")
    }
    
    func testLoginValidation_EmptyUsername() async {
        // Arrange
        viewModel.username = ""
        viewModel.password = "password123"
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertFalse(viewModel.isLoading, "Should not attempt to login if username is empty")
    }
    
    func testLoginValidation_EmptyPassword() async {
        // Arrange
        viewModel.username = "testUser"
        viewModel.password = ""
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertFalse(viewModel.isLoading, "Should not attempt to login if password is empty")
    }
    
    func testLoginValidation_WhitespaceUsername() async {
        // Arrange
        viewModel.username = "   "
        viewModel.password = "password123"
        
        // Act
        await viewModel.login()
        
        // Assert
        XCTAssertFalse(viewModel.isLoading, "Should not attempt to login if username contains only whitespace")
    }
}
