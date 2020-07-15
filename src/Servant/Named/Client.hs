{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
-- | This module just exports orphan instances to make named-servant
-- work with clients
module Servant.Named.Client () where
import Servant.API
import Servant.Client.Core.HasClient
import Servant.Named
import Servant.API.Modifiers
import Data.Proxy
import GHC.TypeLits
import Data.Functor.Identity
import Named

unarg :: NamedF f a name -> f a
unarg (ArgF a) = a

instance (KnownSymbol sym, ToHttpApiData a, HasClient m api)
      => HasClient m (NamedQueryParams sym a :> api) where

  type Client m (NamedQueryParams sym a :> api) =
    sym :! [a] -> Client m api

  clientWithRoute pm Proxy req (Arg paramlist) =
    clientWithRoute pm (Proxy :: Proxy (QueryParams sym a :> api)) req
                    paramlist
                    
  hoistClientMonad pm _ f cl = \as ->
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

  hoistClientMonad pm _ f cl = \arg' ->
    hoistClientMonad pm (Proxy :: Proxy sub) f (cl arg')
