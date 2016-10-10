# -*- encoding: utf-8 -*-
"""WRITE A DOCSTRING."""
from openerp import models, fields, api
from datetime import date, datetime, timedelta
from dateutil.relativedelta import relativedelta
import time as times
# from openerp.exceptions import ValidationError
from ..scripts.api.mikrotik import Mikrotik
import logging

_logger = logging.getLogger(__name__)


class account_analytic_account(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = "account.analytic.account"
    _name = "account.analytic.account"

    username = fields.Char(string="Username")
    password = fields.Char(string="Password")
    ip = fields.Many2one('isp.ip', string="IP Definido")
    device_id = fields.Many2one('isp.device', string="Device")
    box_id = fields.Many2one('isp.box', string="Box")
    net_id = fields.Many2one(
        'isp.net',
        string="SSID",
        domain="[('is_wireless', '=', True)]")
    is_wireless = fields.Boolean(string="Is Wireless")
    is_fiber = fields.Boolean(string="Is Fiber")
    agent = fields.Many2one(
        'res.partner',
        string="Agent monthly",
        domain="[('agent','=',True)]"
    )
    install_agent = fields.Many2one(
        'res.partner',
        string="Agent install",
        domain="[('agent','=',True)]")
    place_id = fields.Many2one('isp', string="Instalation Place")
    upload = fields.Char(string="Upload Contratado", compute="compute_contracted_limits", store=True)
    download = fields.Char(string="Download Contratado", compute="compute_contracted_limits", store=True)
    # internet_user_id = fields.Integer(string="User ID",)

    #date_from = fields.Datetime(string="Date From")
    #date_to = fields.Datetime(string="Date to")
    # grafico = fields.Char(string="Graph", compute="generate_graph")
    late_payment = fields.Boolean("Late Payment")
    is_locked = fields.Boolean(string="Locked", track_visibility="onchange",)
    next_lock = fields.Date(string="Next Lock", track_visibility="onchange",)
    port_redirection_ids = fields.One2many(
        'port.redirection',
        'contract_id',
        string="Redirected Ports")
    next_invoice_due_date = fields.Date(
        string="Invoice Due Date",
        default=fields.Date.today)

    # Related fields for external access
    wireless_router_ip = fields.Char(related="net_id.router_id.ip")
    wireless_router_login = fields.Char(related="net_id.router_id.login")
    wireless_router_password = fields.Char(related="net_id.router_id.password")
    wireless_router_port = fields.Integer(
        related="net_id.router_id.access_port")
    wireless_ap_ip = fields.Char(related="net_id.ap_id.ip")
    wireless_ap_login = fields.Char(related="net_id.ap_id.login")
    wireless_ap_password = fields.Char(related="net_id.ap_id.password")
    wireless_ap_port = fields.Integer(related="net_id.ap_id.access_port")
    client_device_mac = fields.Char(
        related="device_id.serial_id.name", store=True)
    net_id_name = fields.Char(related="net_id.name", store=True)
    ip_address = fields.Char(  # related="ip.name",
         string="IP Address Name", store=True, readonly=True)
    task_ids = fields.One2many(
        'project.task', 'contract_id', string="All Tasks")
    invoice_ids = fields.Many2many(
        'account.invoice', string="Facturas", compute="compute_invoice_ids")
    fixed_ip = fields.Boolean(string="IP Fijo")
    description = fields.Text(track_visibility="onchange")
    access_url = fields.Char(string="Access URL", compute="compute_access_url")

    graph_url = fields.Char(
        string="Gráfico de Sinal", compute="compute_graph_url")
    graph_ping_url = fields.Char(
        string="Gráfico de Ping", compute="compute_graph_url")
    graph_day_url = fields.Char(
        string="Gráfico del Dia", compute="compute_graph_url")
    graph_week_url = fields.Char(
        string="Gráfico de la Semana", compute="compute_graph_url")
    graph_month_url = fields.Char(
        string="Gráfico del Mês", compute="compute_graph_url")
    graph_year_url = fields.Char(
        string="Gráfico del Año", compute="compute_graph_url")
    ip_detected = fields.Char(string="IP Detectado", compute="compute_net_data")
    uptime = fields.Char(
        string="Conectado durante", compute="compute_net_data")
    limit_upload = fields.Char(string="Limite de Upload", compute="compute_net_data")
    limit_download = fields.Char(string="Limite de Download", compute="compute_net_data")
    mac_detected = fields.Char(string="Mac Detectado", compute="compute_net_data")

    @api.one
    def compute_net_data(self):
        """WRITE A DOCSTRING."""
        if not self.username:
            return
        router_connection = Mikrotik(
            host=self.wireless_router_ip,
            username=self.wireless_router_login,
            password=self.wireless_router_password,
            port=self.wireless_router_port)
        if router_connection:
            ip = Mikrotik.get_user_ip(router_connection, self.username)
            _logger.warning("ip: %s"%ip)
            self.ip_detected = ip
            mac = Mikrotik.get_user_mac(router_connection, self.username)
            _logger.warning("mac: %s"%mac)
            self.mac_detected = mac
            band_limit = Mikrotik.get_user_band_limit(router_connection, self.username)
            if band_limit:
                _logger.warning("band_limit: %s" % band_limit)
                self.limit_upload = band_limit['upload']
                self.limit_download = band_limit['download']
            uptime = Mikrotik.get_user_uptime(router_connection, self.username)
            _logger.warning("uptimes: %s"%uptime)
            self.uptime = uptime

    @api.one
    @api.depends('code')
    def compute_graph_url(self):
        """WRITE A DOCSTRING."""
        time = times.time()
        self.graph_url = '<img src=' \
            '"http://neo.sistema.social:82/isp/static/img/%s.png?%s"/>' \
            % (self.code, time)
        self.graph_ping_url = '<img src=' \
            '"http://neo.sistema.social:82/isp/static/img/%s_ping.png?%s"/>' \
            % (self.code, time)
        self.graph_day_url = '<img src=' \
            '"http://neo.sistema.social:82/isp/static/img/%sday.png?%s"/>' \
            % (self.code, time)
        self.graph_week_url = '<img src=' \
            '"http://neo.sistema.social:82/isp/static/img/%sweek.png?%s"/>' \
            % (self.code, time)
        self.graph_month_url = '<img src=' \
            '"http://neo.sistema.social:82/isp/static/img/%smonth.png?%s"/>' \
            % (self.code, time)
        self.graph_year_url = '<img src=' \
            '"http://neo.sistema.social:82/isp/static/img/%syear.png?%s"/>' \
            % (self.code, time)

    @api.one
    @api.depends('ip')
    def compute_access_url(self):
        """WRITE A DOCSTRING."""
        ip = self.ip_detected
        if ip:
            if self.is_wireless:
                self.access_url = \
                    '<a href="http://%s:%s" target="_blank">http://%s:%s</a>' \
                    % (ip, "1771", ip, "1771")
            elif self.is_fiber:
                self.access_url = \
                    '<a href="http://%s" target="_blank">http://%s</a>' \
                    % (ip, ip)
        else:
            self.access_url = False

    @api.one
    @api.depends('partner_id')
    def compute_invoice_ids(self):
        """WRITE A DOCSTRING."""
        overdue_invoices = self.env['account.invoice'].search([
            ('state', '=', 'open'),
            ('date_due', '<=', fields.Date.today()),
            ('origin', '=', self.code)
            ])
        self.invoice_ids = overdue_invoices

    @api.one
    @api.depends('recurring_invoice_line_ids')
    def compute_contracted_limits(self):
        """WRITE A DOCSTRING."""
        for line in self.recurring_invoice_line_ids:
            if line.product_id.is_internet:
                self.upload = "%s%s" % (line.product_id.upload, "M")
                self.download = "%s%s" % (line.product_id.download, "M")

    _sql_constraints = [
        ('username_unique', 'unique(username)',
            'The username is already in use'),
    ]

    @api.onchange('next_invoice_due_date')
    def adjust_create_date(self):
        """WRITE A DOCSTRING."""
        recurring_next_invoice = datetime.strptime(
            self.next_invoice_due_date, '%Y-%m-%d') - timedelta(days=10)
        self.recurring_next_date = datetime.strftime(
            recurring_next_invoice, '%Y-%m-%d')

    @api.one
    def action_unlock(self):
        """WRITE A DOCSTRING."""
        self.sudo().is_locked = False
        five_days_later = date.today() + timedelta(days=5)
        self.sudo().next_lock = five_days_later.strftime('%Y-%m-%d')

        router_connection = Mikrotik(
            host=self.wireless_router_ip,
            username=self.wireless_router_login,
            password=self.wireless_router_password,
            port=self.wireless_router_port)
        Mikrotik.disconnect_user(router_connection, self.username)

    '''@api.one
    @api.onchange('date_from', 'date_to')
    def generate_graph(self):
        """WRITE A DOCSTRING."""
        if not self.date_from:
            one_month_later = date.today() - relativedelta(months=+1)
            date_from = one_month_later.strftime('%Y-%m-%d')
        else:
            date_from = self.date_from

        if not self.date_to:
            today = date.today()
            date_to = today.strftime('%Y-%m-%d')
        else:
            date_to = self.date_to

        # Generate the graph
        str_list = []
        str_list.append("Ping,Tempo,Perdida,Upload,Download")
        table = self.env['isp.monitor'].search([
            ('contract_id', '=', self.id),
            ('create_date', '>=', date_from),
            ('create_date', '<=', date_to)
            ])
        x = 1
        for line in table:
            if x >= len(table):
                break
            str_list.append("{},{},{},{},{}".format(
                line.create_date,
                line.mean,
                line.loss,
                line.upload,
                line.download
            ))
            x += 1
        self.grafico = "\n".join(str_list)
    '''
    @api.model
    def _prepare_invoice_line(self, line, fiscal_position):
        # This method should add calculate commission for the seler
        values = super(account_analytic_account, self)._prepare_invoice_line(
            line, fiscal_position)
        commision_lines = []
        if self.env['account.invoice'].search([
            ('origin', '=', line.analytic_account_id.code)
        ], limit=1):
            commision_lines.append((0, 0, {
                'agent': line.analytic_account_id.agent.id,
                'commission': line.analytic_account_id.agent.commission.id,
            }))
        else:
            # This is the first invoice for this contract
            commision_lines.append((0, 0, {
                'agent': line.analytic_account_id.install_agent.id,
                'commission':
                line.analytic_account_id.install_agent.commission.id,
            }))
        values['agents'] = commision_lines
        return values

    @api.model
    def _prepare_invoice_data(self, contract):
        """WRITE A DOCSTRING."""
        invoice = super(account_analytic_account, self)._prepare_invoice_data(
            contract)
        invoice['date_due'] = contract.next_invoice_due_date
        _logger.warning("type: %s" % contract.type)
        if contract.type == "contract":
                        _logger.warning("id: %s" % contract.id)
                        invoice['contract_id'] = contract.id
                        invoice['journal_id'] = 1

        next_invoice_due_date = datetime.strptime(
            contract.next_invoice_due_date, '%Y-%m-%d') + \
            relativedelta(months=+1)
        contract.next_invoice_due_date = datetime.strftime(
            next_invoice_due_date, '%Y-%m-%d')
        return invoice


class port_redirection(models.Model):
    """Puertas redireccionadas."""

    _inherit = ['mail.thread', 'ir.needaction_mixin']
    _description = "Redirected ports"
    _name = "port.redirection"

    port = fields.Integer(string="Destination Port")
    ip = fields.Char(string="Internal IP")
    reason = fields.Text(string="Reason")
    contract_id = fields.Many2one(
        'account.analytic.account', string="Contract")
