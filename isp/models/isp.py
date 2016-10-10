# -*- encoding: utf-8 -*-
"""
Rossa S.A.

Projeto: Neo Telecom
Data de inicio: 17/08/2015
Programador: Marcelo Pickler
"""

from openerp import models, fields, api
import time
from datetime import date, timedelta  # datetime
from twilio.rest import TwilioRestClient
from openerp.addons.base_geoengine import geo_model
from openerp.addons.base_geoengine import fields as geo_fields
from ..scripts.api.mikrotik import Mikrotik
import logging

_logger = logging.getLogger(__name__)

class isp(geo_model.GeoModel):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP Conexion Point"
    _name = "isp"

    name = fields.Char(string="Name", required=True)
    point = geo_fields.GeoPoint('Coordinate')
    # default="POINT(-6082100.6566597 -2937391.931423402)"
    line = geo_fields.GeoLine(string='Line')
    type = fields.Selection(
        [
            ('client', 'Client'),
            ('wireless', 'Wireless'),
            ('fiber_box', 'Fiber Box'),
            ('fiber', 'Fiber')
        ],
        string="Type", default="client"
    )
    contract_id = fields.Many2one(
        'account.analytic.account',
        string="Contract"
    )
    devices_ids = fields.One2many(
        'isp.device',
        'place_id',
        string="Devices in this place"
    )


class isp_net(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP Net"
    _name = "isp.net"

    name = fields.Char(string="Name", required=True)
    is_wireless = fields.Boolean(string="Is Wireless")
    is_fiber = fields.Boolean(string="Is Fiber")
    router_id = fields.Many2one(
        'isp.device',
        string="Router",
        domain="[('is_router', '=', True)]")
    ap_id = fields.Many2one(
        'isp.device',
        string="Access Point",
        domain="[('is_ap', '=', True)])")
    manager_id = fields.Many2one('isp.manager', string="Manager")
#    ip = fields.Many2one('isp.ip', string="IP Address", required=True)
    allow_unknown = fields.Boolean(
        string="Create unknown username",
        help="""
        Crea automaticamente un contrato cuando un
        username desconocido se conecta a esta red
        """)
    state = fields.Selection(
        [('up', 'Up'), ('down', 'Down')],
        string="State",
        track_visibility="onchange")
    last_change = fields.Datetime(string="Last Change")

    @api.one
    @api.onchange('state')
    def compute_last_change(self):
        """WRITE A DOCSTRING."""
        self.last_change = fields.Datetime.now()


class isp_device(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP Device"
    _name = "isp.device"

    name = fields.Char(string="Name", required=True)
    ip = fields.Char(string="IP Address")
    access_port = fields.Integer(string="Access Port")
    access_url = fields.Char(string="Access URL", compute="compute_access_url")
    is_ap = fields.Boolean(string="Is Acess Point")
    is_router = fields.Boolean(string="Is Router")
    is_olt = fields.Boolean(string="Is OLT")
    is_client = fields.Boolean(string="Is Client")
    login = fields.Char(string="Login")
    password = fields.Char(string="Password")
    serial_id = fields.Many2one('stock.production.lot', string="MAC Address")
    contract_id = fields.Many2one(
        'account.analytic.account',
        string="Contract Id")
    place_id = fields.Many2one('isp', string='Place')

    @api.one
    @api.depends('ip', 'access_port')
    def compute_access_url(self):
        """WRITE A DOCSTRING."""
        access_port = self.access_port
        ip = self.ip
        if ip:
            if access_port:
                self.access_url = \
                    '<a href="http://%s:%s" target="_blank">http://%s:%s</a>' \
                    % (ip, access_port, ip, access_port)
            else:
                self.access_url = \
                    '<a href="http://%s" target="_blank">http://%s</a>' \
                    % (ip, ip)
        else:
            self.access_url = False


class isp_ip(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP IP"
    _name = "isp.ip"

    name = fields.Char(string="IP Address", required=True)
    in_use = fields.Boolean(string="IP Fijo")
    contract_id = fields.Many2one(
        'account.analytic.account',
        string="Contract Id")


class isp_box(models.Model):
    """WRITE A DOCSTRING."""

    # Manages Optic Fiber Network
    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP Box"
    _name = "isp.box"

    name = fields.Char(string="Name", required=True)
    gpon_id = fields.Many2one('isp.gpon', string="GPON")
    place_id = fields.Many2one('isp', string="Place", required=True)


class isp_gpon(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP GPON"
    _name = "isp.gpon"

    name = fields.Char(string="Name", required=True)
    pon_way = fields.Char(string="PON Way", )
    net_id = fields.Many2one('isp.net', string="Network")
    router_id = fields.Many2one('isp.device', string="Router")


class isp_manager(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "ISP Manager"
    _name = "isp.manager"

    name = fields.Char(string="Name", required=True)
    ip = fields.Char(string="IP Address")
    software = fields.Char(string="Software")


class isp_monitor(models.Model):
    """Classes para monitorar el proveedor."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "Network Monitor"
    _name = "isp.monitor"

    contract_id = fields.Many2one(
        'account.analytic.account',
        string="Contract ID")
    name = fields.Char(string="Name", related="contract_id.name", store=True)
    mean = fields.Float(string="Mean", group_operator="avg")
    loss = fields.Integer(string="Loss")
    upload = fields.Integer(string="Upload (MB)")
    download = fields.Integer(string="Download (MB)")
    signal = fields.Integer(string="Signal", group_operator="avg")

    @api.model
    def create(self, vals):
        """
        Create.

        Calculate and record the differential values
        based on the last total values.
        """
        current_upload = vals['upload']
        current_download = vals['download']
        last_register = self.env['isp.monitor.temp'].search([
            ('contract_id', '=', vals['contract_id'])
        ], limit=1)
        if last_register:
            vals['upload'] = current_upload - last_register.upload
            vals['download'] = current_download - last_register.download
            last_register.upload = current_upload
            last_register.download = current_download
            if vals['upload'] < 0:
                vals['upload'] = current_upload
            if vals['download'] < 0:
                vals['download'] = current_download
        else:
            self.env['isp.monitor.temp'].create({
                'contract_id': vals['contract_id'],
                'upload': current_upload,
                'download': current_download,
            })
            vals['upload'] = current_upload
            vals['download'] = current_download
        return super(isp_monitor, self).create(vals)


class isp_monitor_temp(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "Network Monitor Temporary"
    _name = "isp.monitor.temp"

    contract_id = fields.Integer(string="Contract ID", )
    upload = fields.Integer(string="Upload")
    download = fields.Integer(string="Download")


class isp_collector(models.Model):
    """Make the due collection."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "Debt Collector"
    _name = "isp.collector"

    from_number = fields.Char(string="Origin Phone Number")
    sms_generated_invoice = fields.Text(string="Generated Invoice SMS", )
    sms_overdue_invoice = fields.Text(string="Overdue Invoice SMS", )
    block_after = fields.Integer(string="Block after (days)", )
    test_number = fields.Char(string="Test Phone Number")
    account_sid = fields.Char(string="Account SID")
    auth_token = fields.Char(string="Auth Token")

    @api.model
    def check_debt(self):
        """WRITE A DOCSTRING."""
        #client = TwilioRestClient(self.account_sid, self.auth_token)

        five_days_later = date.today() - timedelta(days=self.block_after)
        contract_ids = self.env['account.analytic.account'].search([
            ('state', '=', 'open')
        ])
        for contract in contract_ids:
            invoice_ids = self.env['account.invoice'].search([
                ('state', 'in', ['open', 'draft']),
                ('origin', '=', contract.code)
            ])
            for invoice in invoice_ids:
                if invoice.date_invoice == time.strftime('%Y-%m-%d'):
                    # Send Invoice Generated SMS
                    """body = self.sms_generated_invoice
                    body = body.replace('%DAY', fields.Date.from_string(
                        invoice.date_due).strftime('%d/%m/%Y'))
                    client.messages.create(
                        from_=self.from_number,
                        to=invoice.partner_id.mobile,
                        body=body,
                    )"""
                elif invoice.date_due == time.strftime('%Y-%m-%d'):
                    # Send Overdue Invoice SMS
                    """client.messages.create(
                        from_=self.from_number,
                        to=invoice.partner_id.mobile,
                        body=self.sms_overdue_invoice
                    )"""
                elif invoice.date_due <= five_days_later.strftime('%Y-%m-%d'):
                    # Block the client
                    _logger.warning("Bloquear %s" % contract.code)
                    contract.is_locked = True
                    contract.late_payment = True

                    """TODO: Test this, Disconect the client"""

                    router_connection = Mikrotik(
                        host=contract.wireless_router_ip,
                        username=contract.wireless_router_login,
                        password=contract.wireless_router_password,
                        port=contract.wireless_router_port)
                    Mikrotik.disconnect_user(
                        router_connection, contract.username)

    @api.one
    def send_overdue_test_message(self):
        """WRITE A DOCSTRING."""
        client = TwilioRestClient(self.account_sid, self.auth_token)
        client.messages.create(
            from_=self.from_number,
            to=self.test_number,
            body=self.sms_overdue_invoice
        )

    @api.one
    def send_generated_test_message(self):
        """WRITE A DOCSTRING."""
        client = TwilioRestClient(self.account_sid, self.auth_token)
        client.messages.create(
            from_=self.from_number,
            to=self.test_number,
            body=self.sms_generated_invoice
        )
