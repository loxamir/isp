# -*- encoding: utf-8 -*-
# Projeto: Neo Telecom
# Data de inicio: 02/12/2015
# Programador: Marcelo Pickler

{
	'name': 'ISP Manager Report',
	'description': """

    Create service order report for ISP

    """,
	'category': 'isp',
	'author': 'Marcelo Pickler',
	'website': 'http://www.rossa.com.py',
	'version': '1.0',
	'depends': [
		'isp',
	],
	'data': [
		'reports/reports.xml',
		'reports/report_service_order_view.xml',
	],
	'installable': True,
	'application': False,
}

# vim:expandtab:smartindent:tabstop=4:softtabstop=4:shiftwidth=4:
