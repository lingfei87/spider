module Spider; module Auth
    
    class LoginUser < User
        extend_model superclass, :add_polymorphic => true
        include LoginAuthenticator
        element :username, String, :required => true, :unique => true
        element :password, Password

        def identifier
            username
        end
        
    end
    
end; end