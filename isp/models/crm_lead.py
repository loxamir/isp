# -*- encoding: utf-8 -*-
"""WRITE A DOCSTRING."""

from openerp import models, fields


class crm_lead(models.Model):
    """WRITE A DOCSTRING."""

    _name = 'crm.lead'
    _inherit = 'crm.lead'

    responsible = fields.Boolean(string="Responsible Contacted")
    current_supplier = fields.Many2one(
        'crm.lead.supplier', string="Current Supplier")
    current_speed = fields.Many2one('crm.lead.speed')
    current_price = fields.Float("Current Price")


class crm_lead_supplier(models.Model):
    """WRITE A DOCSTRING."""

    _name = "crm.lead.supplier"

    name = fields.Char("Supplier Name", required=True)


class crm_lead_speed(models.Model):
    """WRITE A DOCSTRING."""

    _name = "crm.lead.speed"

    name = fields.Char("Speed", required=True)
