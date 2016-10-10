# -*- encoding: utf-8 -*-
# Projeto: Neo Telecom
# Data de inicio: 17/08/2015
# Programador: Marcelo Pickler

{
    'name': 'ISP Manager',
    'description': """

    Manages an ISP

    """,
    'category': 'isp',
    'author': 'Rossa S.A.',
    'website': 'http://www.sistema.social',
    'version': '0.1',
    'depends': [
        'base',
        'product',
        'project',
        'account',
        'account_analytic_analysis',
        'stock',
        'widgets',
        'base_geoengine',
        'crm',
    ],
    'data': [
        'security/groups.xml',
        'security/ir.model.access.csv',
        'views/isp_view.xml',
        'views/account_analytic_account_view.xml',
        'views/project_task.xml',
        'views/crm_lead_view.xml',
        'data/account_analytic_journal.xml',
        'views/product_template_view.xml',
        'data/ir_cron.xml',
    ],
    'installable': True,
    'application': True,
}

# vim:expandtab:smartindent:tabstop=4:softtabstop=4:shiftwidth=4:
