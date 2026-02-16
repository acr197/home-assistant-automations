import appdaemon.plugins.hass.hassapi as hass
import cups
import json
import tempfile
import requests
import os

class HelloWorld(hass.Hass):

  def initialize(self):
    self.log("My printing script initialize")
    self.listen_event(self.mode_event, "plz_print_purge")

  def mode_event(self, event, data, kvargs):
    self.log("Starting the print")
    self.print_purge()
    self.log("Print is done!!")

  def print_purge(self):
    cups.setServer("192.168.0.100:631") # <- Your CUPS server IP here!
    conn = cups.Connection(host='192.168.0.100', port=631)# <- Your CUPS server IP here!
     
    # Download the PDF file using requests
    response = requests.get("https://www.testprint.net/wp-content/uploads/2022/05/Testprint-testpage-CMYK.pdf")
    
    # Check if the request was successful (status code 200)
    if response.status_code == 200:
        # Create a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as temp_file:
            temp_file.write(response.content)
            temp_file.flush()
    
            printer = conn.getDefault()

            self.log(f"Printing on {printer}")
    
            # Print the temporary file
            job_id = conn.printFile(printer, temp_file.name, 'Print Job', {})
    
            # Remove the temporary file
            os.unlink(temp_file.name)
    else:
        print("Failed to download the file.")