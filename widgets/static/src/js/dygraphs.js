openerp.widgets = function (instance, local) {

    local.DygraphsWidget = instance.web.form.AbstractField.extend({


        render_value: function () {

            //this.$el.text(this.get("value"));

            new Dygraph(
                this.$el[0],
                this.get("value"),
                {
                    //ylabel: 'Descuento',
                    //xlabel: 'Lectura',
                    fillGraph: true,
                    height: 250
                }
            );

            this.$el.css('overflow', 'hidden');

        }
    });


    instance.web.form.widgets.add('dygraphs', 'instance.widgets.DygraphsWidget');

}
