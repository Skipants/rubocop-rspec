# frozen_string_literal: true

require 'rubocop'
require 'rubocop-rspec'
require 'rubocop/cops_documentation_generator'
require 'yard'

YARD::Rake::YardocTask.new(:yard_for_generate_documentation) do |task|
  task.files = ['lib/rubocop/cop/**/*.rb']
  task.options = ['--no-output']
end

desc 'Generate docs of all cops departments'
task generate_cops_documentation: :yard_for_generate_documentation do
  RuboCop::Cop::Registry.with_temporary_global do
    global = RuboCop::Cop::Registry.global
    # We set a constant for the old cop class, and this skips the
    # `Base.inherited` hook that enlists those old cops.
    %w[
      RuboCop::Cop::RSpec::Capybara::CurrentPathExpectation
      RuboCop::Cop::RSpec::Capybara::MatchStyle
      RuboCop::Cop::RSpec::Capybara::NegationMatcher
      RuboCop::Cop::RSpec::Capybara::SpecificActions
      RuboCop::Cop::RSpec::Capybara::SpecificFinders
      RuboCop::Cop::RSpec::Capybara::SpecificMatcher
      RuboCop::Cop::RSpec::Capybara::VisibilityMatcher
    ].each do |extracted_cop|
      cop = Class.const_get(extracted_cop)
      class << cop
        def badge
          RuboCop::Cop::Badge.for(name)
        end

        def name
          super.sub('::Capybara::', '::RSpec::Capybara::')
        end

        def department
          :'RSpec/Capybara'
        end
      end
      global.enlist(cop)
    end
    %w[
      RuboCop::Cop::RSpec::FactoryBot::AttributeDefinedStatically
      RuboCop::Cop::RSpec::FactoryBot::ConsistentParenthesesStyle
      RuboCop::Cop::RSpec::FactoryBot::CreateList
      RuboCop::Cop::RSpec::FactoryBot::FactoryClassName
      RuboCop::Cop::RSpec::FactoryBot::FactoryNameStyle
      RuboCop::Cop::RSpec::FactoryBot::SyntaxMethods
    ].each do |extracted_cop|
      cop = Class.const_get(extracted_cop)
      class << cop
        def badge
          RuboCop::Cop::Badge.for(name)
        end

        def name
          super.sub('::FactoryBot::', '::RSpec::FactoryBot::')
        end

        def department
          :'RSpec/FactoryBot'
        end
      end
      global.enlist(cop)
    end
    %w[
      RuboCop::Cop::RSpec::Rails::AvoidSetupHook
      RuboCop::Cop::RSpec::Rails::HaveHttpStatus
      RuboCop::Cop::RSpec::Rails::HttpStatus
      RuboCop::Cop::RSpec::Rails::InferredSpecType
      RuboCop::Cop::RSpec::Rails::MinitestAssertions
      RuboCop::Cop::RSpec::Rails::NegationBeValid
      RuboCop::Cop::RSpec::Rails::TravelAround
    ].each do |extracted_cop|
      cop = Class.const_get(extracted_cop)
      class << cop
        def badge
          RuboCop::Cop::Badge.for(name)
        end

        def name
          super.sub('::RSpecRails::', '::RSpec::Rails::')
        end

        def department
          :'RSpec/Rails'
        end
      end
      global.enlist(cop)
    end

    generator = CopsDocumentationGenerator.new(
      departments: %w[RSpec/Capybara RSpec/FactoryBot RSpec/Rails RSpec]
    )
    generator.call
  end
end

desc 'Syntax check for the documentation comments'
task documentation_syntax_check: :yard_for_generate_documentation do
  require 'parser/ruby25'

  ok = true
  YARD::Registry.load!
  cops = RuboCop::Cop::Registry.global
  cops.each do |cop|
    examples = YARD::Registry.all(:class).find do |code_object|
      next unless RuboCop::Cop::Badge.for(code_object.to_s) == cop.badge

      break code_object.tags('example')
    end

    examples.to_a.each do |example|
      buffer = Parser::Source::Buffer.new('<code>', 1)
      buffer.source = example.text
      parser = Parser::Ruby25.new(RuboCop::AST::Builder.new)
      parser.diagnostics.all_errors_are_fatal = true
      parser.parse(buffer)
    rescue Parser::SyntaxError => e
      path = example.object.file
      puts "#{path}: Syntax Error in an example. #{e}"
      ok = false
    end
  end
  abort unless ok
end
