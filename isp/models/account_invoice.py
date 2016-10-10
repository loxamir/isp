# -*- encoding: utf-8 -*-
"""WRITE A DOCSTRING."""
from openerp import models, fields


class AccountInvoice(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = "account.invoice"
    _name = "account.invoice"

    contract_id = fields.Many2one(
        'account.analytic.account', string="Contracto")
