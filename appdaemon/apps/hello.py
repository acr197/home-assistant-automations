import appdaemon.plugins.hass.hassapi as hass
import cups


class HelloWorld(hass.Hass):

  def initialize(self):
    self.log("My printing script initialize")
    self.listen_event(self.mode_event, "plz_print_purge")

  def mode_event(self, event, data, kvargs):
    self.log("Starting the print")
    self.print_purge()
    self.log("Print is done!!")

  def print_purge(self):
    cups.setServer("192.168.0.100:631")
    conn = cups.Connection(host='192.168.0.100', port=631)

    printer = conn.getDefault()
    self.log(f"Printing on {printer}")

    job_id = conn.printFile(printer, "/config/www/print/testpage.pdf", 'Print Job', {})
