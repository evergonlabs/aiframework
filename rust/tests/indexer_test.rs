use std::path::Path;

/// Helper: index a temp directory with known content
fn index_string(filename: &str, content: &str) -> serde_json::Value {
    let dir = tempfile::tempdir().unwrap();
    let file_path = dir.path().join(filename);

    // Create parent dirs if needed
    if let Some(parent) = file_path.parent() {
        std::fs::create_dir_all(parent).unwrap();
    }
    std::fs::write(&file_path, content).unwrap();

    // Also init a git repo so ignore crate works
    std::process::Command::new("git")
        .args(["init", "-q"])
        .current_dir(dir.path())
        .output()
        .unwrap();

    let result = aiframework::indexer::index_repo(dir.path()).unwrap();
    result
}

#[test]
fn test_python_parser() {
    let result = index_string(
        "example.py",
        r#"
import os
from pathlib import Path

class MyClass:
    def method(self, x: int) -> str:
        pass

def public_func(a, b):
    pass

def _private_func():
    pass

MAX_SIZE = 1024
"#,
    );

    let files = result["files"].as_object().unwrap();
    let file = &files["example.py"];
    let symbols = file["symbols"].as_array().unwrap();

    // Check we found all symbols
    let names: Vec<&str> = symbols.iter().map(|s| s["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"MyClass"), "Missing MyClass: {:?}", names);
    assert!(names.contains(&"method"), "Missing method: {:?}", names);
    assert!(names.contains(&"public_func"), "Missing public_func: {:?}", names);
    assert!(names.contains(&"_private_func"), "Missing _private_func: {:?}", names);
    assert!(names.contains(&"MAX_SIZE"), "Missing MAX_SIZE: {:?}", names);

    // Check visibility
    let private = symbols.iter().find(|s| s["name"] == "_private_func").unwrap();
    assert_eq!(private["visibility"], "private");

    // Check method parent
    let method = symbols.iter().find(|s| s["name"] == "method").unwrap();
    assert_eq!(method["parent"], "MyClass");
    assert_eq!(method["kind"], "method");

    // Check imports
    let imports = file["imports"].as_array().unwrap();
    let import_strs: Vec<&str> = imports.iter().map(|i| i.as_str().unwrap()).collect();
    assert!(import_strs.contains(&"os"), "Missing import os: {:?}", import_strs);
    assert!(import_strs.contains(&"pathlib"), "Missing import pathlib: {:?}", import_strs);
}

#[test]
fn test_typescript_parser() {
    let result = index_string(
        "example.ts",
        r#"
import { Foo } from './foo';
import express from 'express';

export interface Config {
    port: number;
}

export class Server {
    async start(port: number) {
        console.log('started');
    }
}

export function createApp(): Server {
    return new Server();
}

export const VERSION = '1.0';
"#,
    );

    let files = result["files"].as_object().unwrap();
    let file = &files["example.ts"];
    let symbols = file["symbols"].as_array().unwrap();

    let names: Vec<&str> = symbols.iter().map(|s| s["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"Config"), "Missing Config: {:?}", names);
    assert!(names.contains(&"Server"), "Missing Server: {:?}", names);
    assert!(names.contains(&"createApp"), "Missing createApp: {:?}", names);
    assert!(names.contains(&"start"), "Missing start method: {:?}", names);

    // Check that start is a method of Server
    let start = symbols.iter().find(|s| s["name"] == "start").unwrap();
    assert_eq!(start["kind"], "method");
    assert_eq!(start["parent"], "Server");

    // Check imports — only local imports (not npm packages)
    let imports = file["imports"].as_array().unwrap();
    let import_strs: Vec<&str> = imports.iter().map(|i| i.as_str().unwrap()).collect();
    assert!(import_strs.contains(&"foo"), "Missing import foo: {:?}", import_strs);
    // 'express' is an npm package, should be filtered
    assert!(!import_strs.contains(&"express"), "Should not include express: {:?}", import_strs);
}

#[test]
fn test_rust_parser() {
    let result = index_string(
        "example.rs",
        r#"
use crate::config;

pub struct App {
    name: String,
}

impl App {
    pub fn new(name: &str) -> Self {
        Self { name: name.to_string() }
    }

    fn internal_method(&self) {}
}

pub trait Handler {
    fn handle(&self);
}

pub enum Status {
    Ok,
    Error(String),
}
"#,
    );

    let files = result["files"].as_object().unwrap();
    let file = &files["example.rs"];
    let symbols = file["symbols"].as_array().unwrap();

    let names: Vec<&str> = symbols.iter().map(|s| s["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"App"), "Missing App: {:?}", names);
    assert!(names.contains(&"new"), "Missing new: {:?}", names);
    assert!(names.contains(&"internal_method"), "Missing internal_method: {:?}", names);
    assert!(names.contains(&"Handler"), "Missing Handler: {:?}", names);
    assert!(names.contains(&"Status"), "Missing Status: {:?}", names);

    // Check method parent
    let new_fn = symbols.iter().find(|s| s["name"] == "new").unwrap();
    assert_eq!(new_fn["kind"], "method");
    assert_eq!(new_fn["parent"], "App");
    assert_eq!(new_fn["visibility"], "public");

    let internal = symbols.iter().find(|s| s["name"] == "internal_method").unwrap();
    assert_eq!(internal["visibility"], "private");
}

#[test]
fn test_go_parser() {
    let result = index_string(
        "example.go",
        r#"
package main

import (
    "fmt"
    "net/http"
)

type Server struct {
    Port int
}

func (s *Server) Start() error {
    return nil
}

func NewServer(port int) *Server {
    return &Server{Port: port}
}
"#,
    );

    let files = result["files"].as_object().unwrap();
    let file = &files["example.go"];
    let symbols = file["symbols"].as_array().unwrap();

    let names: Vec<&str> = symbols.iter().map(|s| s["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"Server"), "Missing Server: {:?}", names);
    assert!(names.contains(&"Start"), "Missing Start: {:?}", names);
    assert!(names.contains(&"NewServer"), "Missing NewServer: {:?}", names);

    // Methods
    let start = symbols.iter().find(|s| s["name"] == "Start").unwrap();
    assert_eq!(start["kind"], "method");
    assert_eq!(start["parent"], "Server");
}

#[test]
fn test_bash_parser() {
    let result = index_string(
        "example.sh",
        r#"#!/usr/bin/env bash

set -euo pipefail

source "$ROOT_DIR/lib/helpers.sh"

my_function() {
    echo "hello"
}

function another_func {
    return 0
}
"#,
    );

    let files = result["files"].as_object().unwrap();
    let file = &files["example.sh"];
    let symbols = file["symbols"].as_array().unwrap();

    let names: Vec<&str> = symbols.iter().map(|s| s["name"].as_str().unwrap()).collect();
    assert!(names.contains(&"my_function"), "Missing my_function: {:?}", names);
    assert!(names.contains(&"another_func"), "Missing another_func: {:?}", names);
}

#[test]
fn test_pagerank() {
    let result = index_string(
        "a.py",
        "from b import foo\ndef func_a(): pass\n",
    );

    // With only 1 file there are no edges to resolve, but PageRank should still work
    let meta = &result["_meta"];
    assert!(meta["total_files"].as_u64().unwrap() >= 1);
}

#[test]
fn test_meta_fields() {
    let result = index_string("test.py", "x = 1\n");

    assert!(result["_meta"]["generated_at"].is_string());
    assert!(result["_meta"]["indexer_version"].is_string());
    assert!(result["_meta"]["total_files"].is_number());
    assert!(result["_meta"]["total_symbols"].is_number());
    assert!(result["_meta"]["total_edges"].is_number());
    assert!(result["_meta"]["elapsed_ms"].is_number());
    assert!(result["_meta"]["languages"].is_object());
    assert!(result["_meta"]["top_files"].is_array());
    assert!(result["files"].is_object());
    assert!(result["symbols"].is_array());
    assert!(result["edges"].is_array());
    assert!(result["modules"].is_object());
}
