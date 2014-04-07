require 'Oj'
require_relative '../spec_helper'

describe Rack::CamelSnake do
  include Rack::Test::Methods

  class MockedApp < Sinatra::Base
    post '/post' do
      Oj.dump(Oj.load(request.body.read))
    end
  end

  def app
    @app ||= Rack::CamelSnake.new(MockedApp)
  end

  describe 'call' do
    let(:json){ { isDone:true, order:1, taskTitle:'hoge' } }

    it 'receives and returns camelCased json' do
      post '/post', Oj.dump(json)
      last_response.body.should eq Oj.dump(json)
    end
  end

  describe 'rewrite_request/response' do
    let(:camel){ { 'taskTitle' => 'hoge' } }
    let(:snake){ { 'task_title' => 'hoge' } }

    it 'rewrite request with content_type == json' do
      mock_env_json = {
        'CONTENT_TYPE' => 'application/json',
        'rack.input' => StringIO.new(Oj.dump(camel))
      }
      app.send(:rewrite_request_body_to_snake, mock_env_json)
      Oj.load(mock_env_json['rack.input'].read).should eq snake
    end

    it 'not rewrite request with another content_type' do
      mock_env_json = {
        'CONTENT_TYPE' => 'text/html',
        'rack.input' => StringIO.new(Oj.dump(camel))
      }
      app.send(:rewrite_request_body_to_snake, mock_env_json)
      Oj.load(mock_env_json['rack.input'].read).should eq camel
    end

    it 'rewrite response with content_type == json' do
      mock_response = [
        200,
        { 'Content-Type' => 'application/json' },
        [ Oj.dump(snake) ]
      ]
      response = app.send(:rewrite_response_body_to_camel, mock_response)
      Oj.load(response[2][0]).should eq camel
      response[1]['Content-Length'].to_i.should eq Oj.dump(camel).bytesize
    end

    it 'not rewrite response with another content_type' do
      mock_response = [
        200,
        { 'Content-Type' => 'text/html' },
        [ Oj.dump(snake) ]
      ]
      response = app.send(:rewrite_response_body_to_camel, mock_response)
      Oj.load(response[2][0]).should eq snake
    end
  end

  describe 'to_snake' do
    it 'convert camel case into snake case' do
      app.send(:to_snake, 'CamelCase').should eq 'camel_case'
      app.send(:to_snake, 'CAMELCase').should eq 'camel_case'
    end
  end

  describe 'to_camel' do
    it 'convert snake case into camel case' do
      %w(_snake_case snake_case snake___case snake_case_).each do |word|
        app.send(:to_camel, word).should eq 'snakeCase'
      end
    end
  end

  describe 'formatter' do
    let!(:snake_hash){ { 'is_done' => 'hoge', 'order' => 1, 'task_title' => 'title' } }
    let!(:camel_hash){ { 'isDone'  => 'hoge', 'order' => 1, 'taskTitle'  => 'title' } }
    let(:snake_array){ [ snake_hash, snake_hash, snake_hash ] }
    let(:camel_array){ [ camel_hash, camel_hash, camel_hash ] }

    context 'given :to_camel' do
      it 'converts keys into camelCase, and the keys should be a string.' do
        app.send(:formatter, snake_hash,  app.send(:key_converter, :to_camel)).should eq camel_hash
        app.send(:formatter, snake_array, app.send(:key_converter, :to_camel)).should eq camel_array
      end
    end

    context 'given :to_snake' do
      it 'converts keys into snake_case, and the keys should be a symbol.' do
        app.send(:formatter, camel_hash,  app.send(:key_converter, :to_snake)).should eq snake_hash
        app.send(:formatter, camel_array, app.send(:key_converter, :to_snake)).should eq snake_array
      end
    end
  end

end
