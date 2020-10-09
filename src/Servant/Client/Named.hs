{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
-- | This module just exports orphan instances to make named-servant
-- work with clients
module Servant.Client.Named () where
import Servant.API
import Servant.Client.Core.HasClient
import Servant.Named
import Servant.API.Modifiers
import Data.Proxy
import GHC.TypeLits
import Data.Maybe
import Data.Functor.Identity
import Named

unarg :: NamedF f a name -> f a
unarg (ArgF a) = a

-- | type family to rewrite a named queryparam to a regular
-- queryparam.  Useful to define instances for classes that extract
-- information from the API type., for example servant-foreign, or
-- servant-swagger.
type family UnNameParam x where
  UnNameParam (NamedQueryParams sym a) = QueryParams sym a
  UnNameParam (NamedQueryParam' mods sym a) = QueryParam' mods sym a
  UnNameParam (NamedQueryFlag sym) = QueryFlag sym

instance (KnownSymbol sym, ToHttpApiData a, HasClient m api)
      => HasClient m (NamedQueryParams sym a :> api) where

  type Client m (NamedQueryParams sym a :> api) =
    sym :? [a] -> Client m api

  clientWithRoute pm Proxy req (ArgF paramlist) =
    clientWithRoute pm (Proxy :: Proxy (QueryParams sym a :> api)) req $
                    fromMaybe [] paramlist
                    
  hoistClientMonad pm _ f cl as =
    hoistClientMonad pm (Proxy :: Proxy api) f (cl as)

instance (KnownSymbol sym, ToHttpApiData a, HasClient m sub,
          SBoolI (FoldRequired mods))
      => HasClient m (NamedQueryParam' mods sym a :> sub) where

  type Client m (NamedQueryParam' mods sym a :> sub) =
    If (FoldRequired mods) (sym :! a) (sym :? a) -> Client m sub

  -- if mparam = Nothing, we don't add it to the query string
  clientWithRoute pm Proxy req mparam =
    clientWithRoute pm (Proxy :: Proxy (QueryParam' mods sym a :> sub)) req $
      case sbool :: SBool (FoldRequired mods) of
        STrue  -> runIdentity (unarg mparam)
        SFalse -> unarg mparam

  hoistClientMonad pm _ f cl arg' =
    hoistClientMonad pm (Proxy :: Proxy sub) f (cl arg')

instance (KnownSymbol sym, HasClient m api)
      => HasClient m (NamedQueryFlag sym :> api) where

  type Client m (NamedQueryFlag sym :> api) =
    sym :! Bool -> Client m api

  clientWithRoute pm Proxy req (Arg paramlist) =
    clientWithRoute pm (Proxy :: Proxy (QueryFlag sym :> api)) req
                    paramlist
                    
  hoistClientMonad pm _ f cl as =
    hoistClientMonad pm (Proxy :: Proxy api) f (cl as)

