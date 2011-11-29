Requirements to run automated tests:
----------------

-Java 1.5+
-Ant  1.6+
-Ruby 1.8.6
-Ruby gems


Automated env setup:
--------------------

Use bundler:

1. sudo gem install bundler
2. sudo bundle install


1. running single test at a time

     a) "ant start-rc"                : start selenium server
     b) ruby tests/whatever_test.rb   : run your test
     c) "ant stop-rc"                 : stop selenium server

2. run specific tests using Rake

     a) "ant start-rc"                : start selenium server
     b) "rake KEYWORDS=whatever"      : run tests corresponding to keyword=whatever
     c) "ant stop-rc"                 : stop selenium server

3. run everything using Ant

     "ant ci -Dtest.base.url=http://valid_url -Dqa.reports=/path/to/output"  :
                        this will start selenium server, execute all available tests, prepare reports  and stop selenium server


Write new tests:
----------------

   - create your test case in: <test_suite_root>/tests/ (eg: logout_test.rb)

Alexandre Berman
