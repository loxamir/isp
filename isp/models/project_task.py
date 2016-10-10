# -*- encoding: utf-8 -*-
"""
Rossa S.A.

Projeto: Neo Telecom
Data de inicio: 18/08/2015
Programador: Marcelo Pickler
"""

from openerp import models, fields, api


class project_task(models.Model):
    """WRITE A DOCSTRING."""

    _inherit = 'project.task'

    used_materials = fields.One2many(
        'project.task.materials', 'related_field', string="Used Materials")
    task_done = fields.Boolean(string="Task Done")
    contract_id = fields.Many2one(
        'account.analytic.account',
        related="project_id.analytic_account_id",
        store=True
    )

    # In the case the user change the stage_id this method will conclud the job
    @api.multi
    def write(self, vals):
        """WRITE A DOCSTRING."""
        if vals.get('stage_id') == self.env.ref(
                'project.project_tt_deployment').id:
            if self.task_done is False:
                self.action_done()
        return super(project_task, self).write(vals)

    @api.one
    def action_done(self):
        """WRITE A DOCSTRING."""
        parent_location = self.env['stock.location'].search([
            ('name', '=', 'Clientes')])
        if not parent_location:
            parent_location = self.env['stock.location'].create({
                'name': 'Clientes',
                'usage': 'internal',
            })
        dst_location = self.env['stock.location'].search([
            ('name', '=', self.project_id.name)])
        if not dst_location:
            dst_location = self.env['stock.location'].create({
                'name': self.project_id.name,
                'usage': 'internal',
                'location_id': parent_location.id
            })
        # Crea un activo para los productos en comodato
        for line in self.used_materials:
            # Registra los gastos en el contrato
            self.env['account.analytic.line'].create({
                'name': self.name,
                'account_id': self.project_id.analytic_account_id.id,
                'journal_id': self.env['account.analytic.journal'].search([
                    ('code', '=', 'INST')]).id,
                'user_id': self.user_id.id,
                'product_id': line.product_id.id,
                'unit_amount': line.qty,
                'product_uom_id': line.product_id.uom_id.id,
                'amount': line.product_id.standard_price*line.qty,
                'general_account_id':
                    line.product_id.categ_id.property_account_income_categ.id,
            })

        # Hace la salida del stock de todos los productos utilizados
        src_location = self.env['ir.model.data'].search([
            ('name', '=', 'stock_location_stock')]).res_id
        stock_picking_lines = []
        transfer_details_items = []
        for line in self.used_materials:
            stock_picking_lines.append((0, 0, {
                'product_id': line.product_id.id,
                'product_uom_qty': line.qty,
                'product_uom': line.product_id.uom_id.id,
                'location_id': src_location,
                'name': line.product_id.name,
                'location_dest_id': dst_location.id,
            }))
            transfer_details_items.append((0, 0, {
                'product_id': line.product_id.id,
                'quantity': line.qty,
                'product_uom_id': line.product_id.uom_id.id,
                'sourceloc_id': src_location,
                'destinationloc_id': dst_location.id,
                'lot_id': line.serial.id,
            }))
        picking = self.env['stock.picking'].create({
            'partner_id': self.project_id.partner_id.id,
            'origin': self.name,
            'picking_type_id': 2,
            'move_lines': stock_picking_lines,
        })
        picking.action_confirm()
        picking.force_assign()

        # Coloca faz a transferencia
        transfer_details = self.env['stock.transfer_details'].with_context(
            active_model='stock.picking'
            ).create({
                'picking_id': picking.id,
                'item_ids': transfer_details_items,
            })
        transfer_details.do_detailed_transfer()
        self.task_done = True
        self.stage_id = self.env.ref('project.project_tt_deployment').id


class project_task_materials(models.Model):
    """WRITE A DOCSTRING."""

    _description = "ISP Instalation"
    _name = "project.task.materials"

    related_field = fields.Many2one('project.task')
    product_id = fields.Many2one(
        'product.product',
        string="Product",
        domain="[('type', '!=', 'service')]")
    qty = fields.Integer(string="Quantity", default="1")
    serial = fields.Many2one(
        'stock.production.lot',
        string="MAC Address",
        domain="[('product_id', '=', product_id)]")
