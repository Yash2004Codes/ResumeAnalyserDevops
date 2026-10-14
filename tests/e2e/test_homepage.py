import os
import socket
import pytest
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

def get_base_url() -> str:
    """Resolve target frontend URL dynamically based on execution environment."""
    if "BASE_URL" in os.environ:
        return os.environ["BASE_URL"]
    # If running inside a Docker network, 'frontend' hostname will resolve
    try:
        socket.gethostbyname("frontend")
        return "http://frontend:3000"
    except socket.gaierror:
        return "http://localhost:3000"

BASE_URL = get_base_url()

@pytest.fixture(scope="module")
def driver():
    """Setup the Selenium WebDriver for Chrome in Headless mode."""
    chrome_options = Options()
    # Headless mode is critical for Jenkins CI/CD as there's no physical display
    chrome_options.add_argument("--headless=new") 
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    
    # Initialize the WebDriver
    driver = webdriver.Chrome(options=chrome_options)
    driver.implicitly_wait(10)
    
    yield driver
    
    # Teardown: close the browser after tests
    driver.quit()

def test_homepage_loads_successfully(driver):
    """Test that the frontend homepage loads without crashing."""
    driver.get(BASE_URL)
    
    # Wait up to 10 seconds for the body tag to be present
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.TAG_NAME, "body"))
    )
    
    # Assert that the page actually loaded (title should not be completely empty)
    assert driver.title != "", "The page title is empty, meaning the page might not have loaded correctly."
    print("Homepage loaded successfully. Page Title:", driver.title)

def test_upload_elements_exist(driver):
    """Verify that file input, upload drop zone, and analyze button are present."""
    driver.get(BASE_URL)
    
    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located((By.ID, "upload-zone"))
    )
    
    file_input = driver.find_element(By.ID, "file-input")
    assert file_input is not None, "File input element with id 'file-input' was not found."
    
    analyze_button = driver.find_element(By.ID, "analyze-button")
    assert analyze_button is not None, "Analyze button with id 'analyze-button' was not found."

