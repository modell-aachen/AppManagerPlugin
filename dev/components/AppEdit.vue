<template>
    <div class="wrapper" v-show="ready">
        <template v-if="true">
            Installname
            <input type="text" v-model="installName"/>
        </template>
        <input type="checkbox" id="expertcheckbox" v-model="expert"/>
        <label for="expertcheckbox">Expert</label>
        <template v-if="expert">
            <p>
                <textarea rows="16" v-model="configAsJson" v-on:input="validateJson()"></textarea>
            </p>
            <p v-if="invalidJson" class="ma-notification ma-failure">
                {{ errorMessage }}
            </p>
        </template>
        <p>
            <button class="button primary" v-on:click="customInstall()" v-bind:disabled="invalidJson" title="Install the app using this configuration">Install</button>
            <button class="button alert" v-on:click="abort()" title="Discard changes">Abort</button>
        </p>
    </div>
</template>

<script>

export default {
    props: ['config', 'index'],
    data: function () {
       return {
           ready: false,
           expert: false,
           configAsJson: "",
           localConfig: "",
           hasCreateFormActions: false,
           invalidJson: false,
           errorMessage: ""
       }
    },
    computed: {
        installName: {
            get: function() {
                return this.localConfig.destinationWeb;
            },
            set: function(input) {
                if(!this.invalidJson) {
                    this.localConfig.destinationWeb = input;
                    this.configAsJson = JSON.stringify(this.localConfig, null, '    ');
                }
            }
        }
    },
    methods: {
        abort: function () {
            this.configAsJson = JSON.stringify(this.localConfig, null, '    ');
            this.ready = false;
            this.$parent.$emit('abort', this.index);
        },
        customInstall: function() {
            this.$parent.$emit('customInstall', this.localConfig);
        },
        validateJson: function() {
            try {
                this.localConfig = JSON.parse(this.configAsJson);
                this.errorMessage = "";
                this.invalidJson = false;
            }
            catch(e) {
                this.errorMessage = e.message;                 
                this.invalidJson = true;           
            }
        }   
    },
    created: function() {
        // make a json string out of the config object
        this.configAsJson = JSON.stringify(this.config, null, '    ');
        // create a copy of the config object
        this.localConfig = $.extend({}, this.config);
        this.ready = true;
    }
}
</script>

<style lang="sass">
</style>