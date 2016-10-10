# -*- encoding: utf-8 -*-
"""
Rossa S.A.

Projeto: Neo Telecom
Data de inicio: 18/08/2015
Programador: Marcelo Pickler
"""

from openerp import models, fields


class product_template(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = "product.template"
    _name = "product.template"

    upload = fields.Float(string="Upload Speed (Mbps)")
    download = fields.Float(string="Download Speed (Mbps)")
    is_internet = fields.Boolean(string="Internet Service")
