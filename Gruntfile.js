/**
 * Created by lvjianyao on 15/12/13.
 */
module.exports = function(grunt) {

  // 加载"grunt-jsdoc"插件..
  grunt.loadNpmTasks('grunt-jsdoc');

  // 项目配置信息.

  grunt.initConfig({

    pkg: grunt.file.readJSON('package.json'),

    jsdoc : {
      dist : {
        src: ['lib/*.js', 'test/*.js'],
        options: {
          destination: 'doc'
        }
      }
    }

  });

  // 注册默认任务.
  grunt.registerTask('default', ['grunt-jsdoc']);


};