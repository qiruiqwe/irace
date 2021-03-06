# =========================================================================
# irace: An implementation in R of Iterated Race.
# -------------------------------------------------------------------------
#
#  Copyright (C) 2010-2020
#  Manuel López-Ibáñez     <manuel.lopez-ibanez@manchester.ac.uk> 
#  Jérémie Dubois-Lacoste  <jeremie.dubois-lacoste@ulb.ac.be>
#  Leslie Perez Caceres    <leslie.perez.caceres@ulb.ac.be>
#
# -------------------------------------------------------------------------
#  This program is free software (software libre); you can redistribute
#  it and/or modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2 of the
#  License, or (at your option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, you can obtain a copy of the GNU
#  General Public License at:
#                  http://www.gnu.org/copyleft/gpl.html
#  or by writing to the  Free Software Foundation, Inc., 59 Temple Place,
#                  Suite 330, Boston, MA 02111-1307 USA
# -------------------------------------------------------------------------
# $Revision$
# =========================================================================

#' irace.license
#'
#' A character string containing the license information of \pkg{irace}.
#' 
#' @export
## __VERSION__ below will be replaced by the version defined in R/version.R
## This avoids constant conflicts within this file.
irace.license <-
'#------------------------------------------------------------------------------
# irace: An implementation in R of (Elitist) Iterated Racing
# Version: __VERSION__
# Copyright (C) 2010-2020
# Manuel Lopez-Ibanez     <manuel.lopez-ibanez@manchester.ac.uk>
# Jeremie Dubois-Lacoste  
# Leslie Perez Caceres    <leslie.perez.caceres@ulb.ac.be>
#
# This is free software, and you are welcome to redistribute it under certain
# conditions.  See the GNU General Public License for details. There is NO
# WARRANTY; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# irace builds upon previous code from the race package:
#     race: Racing methods for the selection of the best
#     Copyright (C) 2003 Mauro Birattari
#------------------------------------------------------------------------------
'
cat.irace.license <- function()
{
  cat(sub("__VERSION__", irace.version, irace.license, fixed=TRUE))
}

  
#' irace.usage
#'
#' \code{irace.usage}  This function prints all command-line options of \pkg{irace},
#'   with the corresponding switches and a short description.
#' 
#' @author Manuel López-Ibáñez and Jérémie Dubois-Lacoste
#' @export
irace.usage <- function ()
{
  cat.irace.license()
  cat ("# installed at: ", system.file(package="irace"), "\n", sep = "")
  cmdline_usage(.irace.params.def)
}

#' irace.main
#'
#' \code{irace.main} is a higher-level interface to invoke \code{\link{irace}}.
#' 
#' @template arg_scenario
#' 
#' @param output.width (\code{integer(1)}) The width that must be used for the screen
#' output.
#'
#' @details  The function \code{irace.main} checks the correctness of the
#' scenario, prints it, reads the parameter space from
#' \code{scenario$parameterFile}, invokes \code{\link{irace}} and
#' prints its results in various formatted ways. If you want a
#' lower-level interface, please see function \code{\link{irace}}.
#'
#' @templateVar return_invisible TRUE
#' @template return_irace
#' @seealso
#'  \code{\link{irace.cmdline}} a higher-level command-line interface to
#'  \code{irace.main}.
#'  \code{\link{readScenario}} to read the scenario setup from  a file.
#'  \code{\link{defaultScenario}} to provide a default scenario for \pkg{irace}.
#' 
#' @author Manuel López-Ibáñez and Jérémie Dubois-Lacoste
#' @export
irace.main <- function(scenario = defaultScenario(), output.width = 9999L)
{
  op <- options(width = output.width) # Do not wrap the output.
  on.exit(options(op), add = TRUE)

  scenario <- checkScenario (scenario)
  debug.level <- scenario$debugLevel
  
  if (debug.level >= 1) {
    op.debug <- options(warning.length = 8170,
                        error = if (interactive()) utils::recover
                                else irace.dump.frames)
    on.exit(options(op.debug), add = TRUE)
    printScenario (scenario)
  }
  
  # Read parameters definition
  parameters <- readParameters (file = scenario$parameterFile,
                                digits = scenario$digits,
                                debugLevel = debug.level)
						
  if (debug.level >= 2) { irace.note("Parameters have been read\n") }
  
  eliteConfigurations <- irace (scenario = scenario, parameters = parameters)
  
  cat("# Best configurations (first number is the configuration ID;",
      " listed from best to worst according to the ",
      test.type.order.str(scenario$testType), "):\n", sep = "")
  configurations.print(eliteConfigurations)
  
  cat("# Best configurations as commandlines (first number is the configuration ID; same order as above):\n")
  configurations.print.command (eliteConfigurations, parameters)
  
  if (scenario$postselection > 0) 
    psRace(iraceLogFile=scenario$logFile, postselection=scenario$postselection, elites=TRUE)
  
  testing_fromlog(logFile = scenario$logFile)
  
  invisible(eliteConfigurations)
}

#' Test configurations given in `.Rdata` file
#'
#' `testing_fromlog` executes the testing of the target algorithm configurations
#' found by an \pkg{irace} execution.
#' 
#' @param logFile Path to the `.Rdata` file produced by \pkg{irace}.
#'
#' @param testNbElites Number of (final) elite configurations to test. Overrides
#'   the value found in `logFile`.
#' 
#' @param testIterationElites (`logical(1)`) If `FALSE`, only the final
#'   `testNbElites` configurations are tested; otherwise, also test the best
#'   configurations of each iteration. Overrides the value found in `logFile`.
#'
#' @param testInstancesDir  Directory where testing instances are located, either absolute or relative to current directory.
#'
#' @param testInstancesFile File containing a list of test instances and optionally additional parameters for them.
#'
#' @param testInstances Character vector of the instances to be used in the `targetRunner` when executing the testing.
#'
#' @return Boolean. `TRUE` if the testing ended successfully otherwise, `FALSE`.
#' 
#' @details The function `testing_fromlog` loads the `logFile` and obtains the
#'   testing setup and configurations to be tested.  Within the `logFile`, the
#'   variable `scenario$testNbElites` specifies how many final elite
#'   configurations to test and `scenario$testIterationElites` indicates
#'   whether test the best configuration of each iteration. The values may be
#'   overridden by setting the corresponding arguments in this function.  The
#'   set of testing instances must appear in `scenario[["testInstances"]]`.
#'
#' @seealso [defaultScenario()] to provide a default scenario for \pkg{irace}.
#' [testing_fromfile()] provides a different interface for testing.
#' 
#' @author Manuel López-Ibáñez and Leslie Pérez Cáceres
#' @md
#' @export
testing_fromlog <- function(logFile, testNbElites, testIterationElites,
                            testInstancesDir, testInstancesFile, testInstances)
{
  if (is.null.or.empty(logFile)) {
    irace.note("No logFile provided to perform the testing of configurations. Skipping testing.\n")
    return(FALSE)
  }
  
  file.check(logFile, readable = TRUE, text = "irace log file")

  load(logFile)
  scenario <- iraceResults[["scenario"]]
  parameters <- iraceResults[["parameters"]]
  instances_changed <- FALSE
  
  if (!missing(testNbElites))
    scenario[["testNbElites"]] <- testNbElites
  if (!missing(testIterationElites))
    scenario$testIterationElites <- testIterationElites

  if (!missing(testInstances)) {
    scenario[["testInstances"]] <- testInstances
  }
  
  if (!missing(testInstancesDir)) {
    scenario$testInstancesDir <- testInstancesDir
    instances_changed <- TRUE
  }
  if (!missing(testInstancesFile)) {
    scenario$testInstancesFile <- testInstancesFile
    instances_changed <- TRUE
  }
  
  cat("\n\n# Testing of elite configurations:", scenario$testNbElites, 
      "\n# Testing iteration configurations:", scenario$testIterationElites,"\n")
  if (scenario$testNbElites <= 0)
    return (FALSE)

  # If they are already setup, don't change them.
  if (instances_changed || is.null.or.empty(scenario[["testInstances"]])) {
    scenario <- setup_test_instances(scenario)
    if (is.null.or.empty(scenario[["testInstances"]])) {
      irace.note("No test instances, skip testing")
      return(FALSE)
    }
  }
  
  # Get configurations that will be tested
  if (scenario$testIterationElites)
    testing_id <- sapply(iraceResults$allElites, function(x)
      x[1:min(length(x), scenario$testNbElites)])
  else {
    tmp <- iraceResults$allElites[[length(iraceResults$allElites)]]
    testing_id <- tmp[1:min(length(tmp), scenario$testNbElites)]
  }
  testing_id <- unique.default(testing_id)
  configurations <- iraceResults$allConfigurations[testing_id, , drop=FALSE]

  irace.note ("Testing configurations (in no particular order): ", paste(testing_id, collapse=" "), "\n")
  configurations.print(configurations)  
  
  iraceResults$testing <- testConfigurations(configurations, scenario, parameters)
  irace_save_logfile (iraceResults, scenario)
  # FIXME : We should print the seeds also. As an additional column?
  irace.note ("Testing results (column number is configuration ID in no particular order):\n")
  print(iraceResults$testing$experiments)
  irace.note ("Finished testing\n")
  return(TRUE)
}

#' Test configurations given an explicit table of configurations and a scenario file
#'
#' `testing_fromfile` executes the testing of an explicit list of configurations
#' given `filename`. A `logFile` is created unless disabled `scenario`. This
#' may overwrite an existing one!`
#' 
#' @param filename Path to a file containing configurations: one configuration
#'   per line, one parameter per column, parameter names in header.
#'
#' @template arg_scenario
#'
#' @return iraceResults
#'
#' @seealso [testing_fromlog()] provides a different interface for testing.
#' 
#' @author Manuel López-Ibáñez
#' @md
#' @export
testing_fromfile <- function(filename, scenario)
{
  irace.note ("Checking scenario\n")
  scenario <- checkScenario(scenario)
  printScenario(scenario)

  irace.note("Reading parameter file '", scenario$parameterFile, "'.\n")
  parameters <- readParameters (file = scenario$parameterFile,
                                digits = scenario$digits)
  allConfigurations <- readConfigurationsFile (filename, parameters)
  allConfigurations <- cbind(.ID. = 1:nrow(allConfigurations),
                             allConfigurations,
                             .PARENT. = NA)
  rownames(allConfigurations) <- allConfigurations$.ID.
  num <- nrow(allConfigurations)
  allConfigurations <- checkForbidden(allConfigurations, scenario$forbiddenExps)
  if (nrow(allConfigurations) < num) {
    irace.warning("Some of the configurations in the configurations file were forbidden",
                  "and, thus, discarded")
  }

  # To save the logs
  iraceResults <- list(scenario = scenario,
                       irace.version = irace.version,
                       parameters = parameters,
                       allConfigurations = allConfigurations)
    
  irace.note ("Testing configurations (in the order given as input): \n")
  configurations.print(allConfigurations)  
  iraceResults$testing <- testConfigurations(allConfigurations, scenario, parameters)

  # FIXME : We should print the seeds also. As an additional column?
  irace.note ("Testing results (column number is configuration ID in no particular order):\n")
  print(iraceResults$testing$experiments)
  irace_save_logfile(iraceResults, scenario)
  irace.note ("Finished testing\n")
  return(iraceResults)
}

#' Test that the given irace scenario can be run.
#'
#' @description \code{checkIraceScenario} tests that the given irace scenario
#'   can be run by checking the scenario settings provided and trying to run
#'   the target-algorithm.
#' 
#' @template arg_scenario
#' @template arg_parameters
#'
#' @return returns \code{TRUE} if succesful and gives an error and returns
#' \code{FALSE} otherwise.
#' 
#' @details Provide the \code{parameters} argument only if the parameter list
#'   should not be obtained from the parameter file given by the scenario. If
#'   the parameter list is provided it will not be checked. This function will
#'   try to execute the target-algorithm.
#'
#' @seealso
#'  \describe{
#'  \item{\code{\link{readScenario}}}{for reading a configuration scenario from a file.}
#'  \item{\code{\link{printScenario}}}{prints the given scenario.}
#'  \item{\code{\link{defaultScenario}}}{returns the default scenario settings of \pkg{irace}.}
#'  \item{\code{\link{checkScenario}}}{to check that the scenario is valid.}
#' }
#' 
#' @author Manuel López-Ibáñez and Jérémie Dubois-Lacoste
#' @export
checkIraceScenario <- function(scenario, parameters = NULL)
{
  irace.note ("Checking scenario\n")
  scenario$debugLevel <- 2 
  scenario <- checkScenario(scenario)
  printScenario(scenario)
 
  if (is.null(parameters)) {
    irace.note("Reading parameter file '", scenario$parameterFile, "'.\n")
    parameters <- readParameters (file = scenario$parameterFile,
                                  digits = scenario$digits,
                                  debugLevel = 2)
  } else if (!is.null.or.empty(scenario$parameterFile)) {
    cat("# Parameters provided by user.\n",
        "# Parameter file '", scenario$parameterFile, "' will be ignored\n", sep = "")
  }
  checkParameters(parameters)
  irace.note("Checking target execution.\n")
  if (checkTargetFiles(scenario = scenario, parameters = parameters)) {
    irace.note("Check succesful.\n")
    return(TRUE)
  } else {
    irace.error("Check unsuccessful.\n")
    return(FALSE)
  }
}


#' irace.cmdline
#'
#' \code{irace.cmdline} starts \pkg{irace} using the parameters
#'  of the command line used to invoke R.
#' 
#' @param argv (\code{character()}) \cr The arguments 
#' provided on the R command line as a character vector, e.g., 
#' \code{c("--scenario", "scenario.txt", "-p", "parameters.txt")}.
#' Using the  default value (not providing the parameter) is the 
#' easiest way to call \code{irace.cmdline}.
#' 
#' @details The function reads the parameters given on the command line
#' used to invoke R, finds the name of the scenario file,
#'  initializes the scenario from the file (with the function
#'  \code{\link{readScenario}}) and possibly from parameters passed on
#'  the command line. It finally starts \pkg{irace} by calling
#'  \code{\link{irace.main}}.
#'
#' @templateVar return_invisible TRUE
#' @template return_irace
#' 
#' @seealso
#'  \code{\link{irace.main}} to start \pkg{irace} with a given scenario.
#' 
#' @author Manuel López-Ibáñez and Jérémie Dubois-Lacoste
#' @export
irace.cmdline <- function(argv = commandArgs (trailingOnly = TRUE))
{
  parser <- CommandArgsParser$new(argv = argv, argsdef = .irace.params.def)
  if (!is.null(parser$readArg (short = "-h", long = "--help"))) {
    irace.usage()
    return(invisible(NULL))
  }

  if (!is.null(parser$readArg (short = "-v", long = "--version"))) {
    cat.irace.license()
    cat ("# installed at: ", system.file(package="irace"), "\n", sep = "")
    print(citation(package="irace"))
    return(invisible(NULL))
  }
  cat.irace.license()
  cat ("# installed at: ", system.file(package="irace"), "\n",
       "# called with: ", paste(argv, collapse = " "), "\n", sep = "")
  
  # Read the scenario file and the command line
  scenarioFile <- parser$readCmdLineParameter ("scenarioFile", default = "")
  scenario <- readScenario(scenarioFile)
  for (param in .irace.params.names) {
    scenario[[param]] <-
      parser$readCmdLineParameter(paramName = param,
                                  default = scenario[[param]])
  }
 
  # Check scenario
  if (!is.null(parser$readArg (short = "-c", long = "--check"))) {
    checkIraceScenario(scenario)
    return(invisible(NULL))
  }

  # Only do testing
  testFile <- parser$readArg (long = "--only-test")
  if (!is.null(testFile)) {
    return(invisible(testing_fromfile(testFile, scenario)))
  }

  if (length(parser$argv) > 0) {
    irace.error ("Unknown command-line options: ", paste(parser$argv, collapse = " "))
  }
  
  irace.main(scenario)
}
